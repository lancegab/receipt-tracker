import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { HTTPException } from 'hono/http-exception';
import { v4 as uuidv4 } from 'uuid';
import { db } from '../db/index.js';
import {
  budgetGroups,
  budgetGroupMembers,
  budgetGroupInvitations,
  users,
} from '../db/schema.js';
import { eq, and } from 'drizzle-orm';
import { authMiddleware } from '../middleware/auth.js';
import {
  createBudgetGroupSchema,
  updateBudgetGroupSchema,
  inviteMemberSchema,
} from '../validators/index.js';
import type { AppEnv } from '../types/index.js';

const budgetGroupsRouter = new Hono<AppEnv>();
budgetGroupsRouter.use('*', authMiddleware);

// Helper: verify user is a member of the group and get their role
async function verifyGroupMembership(
  groupId: string,
  userId: string
): Promise<{ role: string }> {
  const [membership] = await db
    .select()
    .from(budgetGroupMembers)
    .where(
      and(
        eq(budgetGroupMembers.groupId, groupId),
        eq(budgetGroupMembers.userId, userId)
      )
    );
  if (!membership) {
    throw new HTTPException(403, { message: 'Not a member of this group' });
  }
  return { role: membership.role };
}

// GET /api/budget-groups
budgetGroupsRouter.get('/', async (c) => {
  const user = c.get('user');

  const memberships = await db
    .select({
      groupId: budgetGroupMembers.groupId,
      role: budgetGroupMembers.role,
    })
    .from(budgetGroupMembers)
    .where(eq(budgetGroupMembers.userId, user.id));

  if (memberships.length === 0) {
    return c.json({ success: true, data: [] });
  }

  const groupIds = memberships.map((m) => m.groupId);
  const groups = [];

  for (const gId of groupIds) {
    const [group] = await db
      .select()
      .from(budgetGroups)
      .where(eq(budgetGroups.id, gId));
    if (group) {
      const membership = memberships.find((m) => m.groupId === gId);
      groups.push({ ...group, myRole: membership?.role });
    }
  }

  return c.json({ success: true, data: groups });
});

// POST /api/budget-groups
budgetGroupsRouter.post(
  '/',
  zValidator('json', createBudgetGroupSchema),
  async (c) => {
    const user = c.get('user');
    const body = c.req.valid('json');

    const groupId = uuidv4();
    await db.insert(budgetGroups).values({
      id: groupId,
      name: body.name,
      description: body.description || null,
      currency: body.currency,
      createdBy: user.id,
    });

    // Auto-add creator as owner
    await db.insert(budgetGroupMembers).values({
      id: uuidv4(),
      groupId,
      userId: user.id,
      role: 'owner',
    });

    const [created] = await db
      .select()
      .from(budgetGroups)
      .where(eq(budgetGroups.id, groupId));

    return c.json({ success: true, data: created }, 201);
  }
);

// GET /api/budget-groups/:id
budgetGroupsRouter.get('/:id', async (c) => {
  const user = c.get('user');
  const groupId = c.req.param('id');

  await verifyGroupMembership(groupId, user.id);

  const [group] = await db
    .select()
    .from(budgetGroups)
    .where(eq(budgetGroups.id, groupId));

  if (!group) {
    throw new HTTPException(404, { message: 'Group not found' });
  }

  // Get members with user info
  const members = await db
    .select({
      id: budgetGroupMembers.id,
      userId: budgetGroupMembers.userId,
      role: budgetGroupMembers.role,
      joinedAt: budgetGroupMembers.joinedAt,
      email: users.email,
      displayName: users.displayName,
    })
    .from(budgetGroupMembers)
    .innerJoin(users, eq(budgetGroupMembers.userId, users.id))
    .where(eq(budgetGroupMembers.groupId, groupId));

  return c.json({ success: true, data: { ...group, members } });
});

// PATCH /api/budget-groups/:id
budgetGroupsRouter.patch(
  '/:id',
  zValidator('json', updateBudgetGroupSchema),
  async (c) => {
    const user = c.get('user');
    const groupId = c.req.param('id');
    const body = c.req.valid('json');

    const { role } = await verifyGroupMembership(groupId, user.id);
    if (role !== 'owner') {
      throw new HTTPException(403, {
        message: 'Only the owner can update the group',
      });
    }

    const updates: Record<string, unknown> = {};
    if (body.name !== undefined) updates.name = body.name;
    if (body.description !== undefined) updates.description = body.description;

    if (Object.keys(updates).length > 0) {
      await db
        .update(budgetGroups)
        .set(updates)
        .where(eq(budgetGroups.id, groupId));
    }

    const [updated] = await db
      .select()
      .from(budgetGroups)
      .where(eq(budgetGroups.id, groupId));

    return c.json({ success: true, data: updated });
  }
);

// DELETE /api/budget-groups/:id
budgetGroupsRouter.delete('/:id', async (c) => {
  const user = c.get('user');
  const groupId = c.req.param('id');

  const { role } = await verifyGroupMembership(groupId, user.id);
  if (role !== 'owner') {
    throw new HTTPException(403, {
      message: 'Only the owner can delete the group',
    });
  }

  await db.delete(budgetGroups).where(eq(budgetGroups.id, groupId));
  return c.json({ success: true, data: { message: 'Group deleted' } });
});

// POST /api/budget-groups/:id/invite
budgetGroupsRouter.post(
  '/:id/invite',
  zValidator('json', inviteMemberSchema),
  async (c) => {
    const user = c.get('user');
    const groupId = c.req.param('id');
    const { email } = c.req.valid('json');

    const { role } = await verifyGroupMembership(groupId, user.id);
    if (role !== 'owner') {
      throw new HTTPException(403, {
        message: 'Only the owner can invite members',
      });
    }

    // Check if already a member
    const [existingUser] = await db
      .select()
      .from(users)
      .where(eq(users.email, email));

    if (existingUser) {
      const [existingMember] = await db
        .select()
        .from(budgetGroupMembers)
        .where(
          and(
            eq(budgetGroupMembers.groupId, groupId),
            eq(budgetGroupMembers.userId, existingUser.id)
          )
        );
      if (existingMember) {
        throw new HTTPException(400, {
          message: 'User is already a member of this group',
        });
      }
    }

    // Check for pending invitation
    const [pendingInvite] = await db
      .select()
      .from(budgetGroupInvitations)
      .where(
        and(
          eq(budgetGroupInvitations.groupId, groupId),
          eq(budgetGroupInvitations.invitedEmail, email),
          eq(budgetGroupInvitations.status, 'pending')
        )
      );

    if (pendingInvite) {
      throw new HTTPException(400, {
        message: 'An invitation is already pending for this email',
      });
    }

    const inviteId = uuidv4();
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);

    await db.insert(budgetGroupInvitations).values({
      id: inviteId,
      groupId,
      invitedEmail: email,
      invitedBy: user.id,
      status: 'pending',
      expiresAt,
    });

    const [created] = await db
      .select()
      .from(budgetGroupInvitations)
      .where(eq(budgetGroupInvitations.id, inviteId));

    return c.json({ success: true, data: created }, 201);
  }
);

// POST /api/budget-groups/:id/members/:memberId/remove
budgetGroupsRouter.post('/:id/members/:memberId/remove', async (c) => {
  const user = c.get('user');
  const groupId = c.req.param('id');
  const memberId = c.req.param('memberId');

  const { role } = await verifyGroupMembership(groupId, user.id);
  if (role !== 'owner') {
    throw new HTTPException(403, {
      message: 'Only the owner can remove members',
    });
  }

  // Can't remove yourself
  const [member] = await db
    .select()
    .from(budgetGroupMembers)
    .where(eq(budgetGroupMembers.id, memberId));

  if (!member) {
    throw new HTTPException(404, { message: 'Member not found' });
  }
  if (member.userId === user.id) {
    throw new HTTPException(400, { message: 'Cannot remove yourself' });
  }

  await db
    .delete(budgetGroupMembers)
    .where(eq(budgetGroupMembers.id, memberId));

  return c.json({ success: true, data: { message: 'Member removed' } });
});

// GET /api/budget-groups/invitations
budgetGroupsRouter.get('/invitations', async (c) => {
  const user = c.get('user');

  // Get user email
  const [userData] = await db
    .select({ email: users.email })
    .from(users)
    .where(eq(users.id, user.id));

  if (!userData) {
    throw new HTTPException(404, { message: 'User not found' });
  }

  const invitations = await db
    .select({
      id: budgetGroupInvitations.id,
      groupId: budgetGroupInvitations.groupId,
      invitedEmail: budgetGroupInvitations.invitedEmail,
      invitedBy: budgetGroupInvitations.invitedBy,
      status: budgetGroupInvitations.status,
      createdAt: budgetGroupInvitations.createdAt,
      expiresAt: budgetGroupInvitations.expiresAt,
      groupName: budgetGroups.name,
    })
    .from(budgetGroupInvitations)
    .innerJoin(
      budgetGroups,
      eq(budgetGroupInvitations.groupId, budgetGroups.id)
    )
    .where(
      and(
        eq(budgetGroupInvitations.invitedEmail, userData.email),
        eq(budgetGroupInvitations.status, 'pending')
      )
    );

  return c.json({ success: true, data: invitations });
});

// POST /api/budget-groups/invitations/:id/accept
budgetGroupsRouter.post('/invitations/:id/accept', async (c) => {
  const user = c.get('user');
  const inviteId = c.req.param('id');

  const [userData] = await db
    .select({ email: users.email })
    .from(users)
    .where(eq(users.id, user.id));

  const [invitation] = await db
    .select()
    .from(budgetGroupInvitations)
    .where(
      and(
        eq(budgetGroupInvitations.id, inviteId),
        eq(budgetGroupInvitations.invitedEmail, userData!.email),
        eq(budgetGroupInvitations.status, 'pending')
      )
    );

  if (!invitation) {
    throw new HTTPException(404, {
      message: 'Invitation not found or already handled',
    });
  }

  // Check expiration
  if (new Date() > new Date(invitation.expiresAt)) {
    await db
      .update(budgetGroupInvitations)
      .set({ status: 'expired' })
      .where(eq(budgetGroupInvitations.id, inviteId));
    throw new HTTPException(400, { message: 'Invitation has expired' });
  }

  // Add to group
  await db.insert(budgetGroupMembers).values({
    id: uuidv4(),
    groupId: invitation.groupId,
    userId: user.id,
    role: 'member',
  });

  // Mark invitation as accepted
  await db
    .update(budgetGroupInvitations)
    .set({ status: 'accepted' })
    .where(eq(budgetGroupInvitations.id, inviteId));

  return c.json({
    success: true,
    data: { message: 'Invitation accepted' },
  });
});

// POST /api/budget-groups/invitations/:id/decline
budgetGroupsRouter.post('/invitations/:id/decline', async (c) => {
  const user = c.get('user');
  const inviteId = c.req.param('id');

  const [userData] = await db
    .select({ email: users.email })
    .from(users)
    .where(eq(users.id, user.id));

  const [invitation] = await db
    .select()
    .from(budgetGroupInvitations)
    .where(
      and(
        eq(budgetGroupInvitations.id, inviteId),
        eq(budgetGroupInvitations.invitedEmail, userData!.email),
        eq(budgetGroupInvitations.status, 'pending')
      )
    );

  if (!invitation) {
    throw new HTTPException(404, {
      message: 'Invitation not found or already handled',
    });
  }

  await db
    .update(budgetGroupInvitations)
    .set({ status: 'declined' })
    .where(eq(budgetGroupInvitations.id, inviteId));

  return c.json({
    success: true,
    data: { message: 'Invitation declined' },
  });
});

export default budgetGroupsRouter;
