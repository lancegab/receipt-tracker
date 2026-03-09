import 'dotenv/config';
import { db } from './index.js';
import { categories } from './schema.js';
import { eq } from 'drizzle-orm';
import { v4 as uuidv4 } from 'uuid';

const defaultExpenseCategories = [
  { name: 'Food & Dining', icon: 'restaurant', color: '#FF6B6B' },
  { name: 'Groceries', icon: 'shopping_cart', color: '#4ECDC4' },
  { name: 'Transportation', icon: 'directions_car', color: '#45B7D1' },
  { name: 'Shopping', icon: 'shopping_bag', color: '#96CEB4' },
  { name: 'Entertainment', icon: 'movie', color: '#FFEAA7' },
  { name: 'Bills & Utilities', icon: 'receipt_long', color: '#DDA0DD' },
  { name: 'Healthcare', icon: 'local_hospital', color: '#98D8C8' },
  { name: 'Personal Care', icon: 'spa', color: '#F7DC6F' },
  { name: 'Education', icon: 'school', color: '#82E0AA' },
  { name: 'Travel', icon: 'flight', color: '#85C1E9' },
  { name: 'Home', icon: 'home', color: '#F0B27A' },
  { name: 'Gifts & Donations', icon: 'card_giftcard', color: '#D7BDE2' },
  { name: 'Other', icon: 'more_horiz', color: '#BDC3C7' },
];

const defaultIncomeCategories = [
  { name: 'Salary', icon: 'work', color: '#27AE60' },
  { name: 'Freelance', icon: 'laptop', color: '#2ECC71' },
  { name: 'Investment', icon: 'trending_up', color: '#1ABC9C' },
  { name: 'Gift', icon: 'redeem', color: '#3498DB' },
  { name: 'Refund', icon: 'replay', color: '#9B59B6' },
  { name: 'Other Income', icon: 'attach_money', color: '#F39C12' },
];

async function seed() {
  console.log('Seeding default categories...');

  // Check if system categories already exist
  const existing = await db.select().from(categories).where(eq(categories.isSystem, true)).limit(1);
  if (existing.length > 0) {
    console.log('System categories already exist, skipping seed.');
    process.exit(0);
  }

  const expenseValues = defaultExpenseCategories.map((cat) => ({
    id: uuidv4(),
    userId: null,
    name: cat.name,
    type: 'expense' as const,
    icon: cat.icon,
    color: cat.color,
    isSystem: true,
    isActive: true,
  }));

  const incomeValues = defaultIncomeCategories.map((cat) => ({
    id: uuidv4(),
    userId: null,
    name: cat.name,
    type: 'income' as const,
    icon: cat.icon,
    color: cat.color,
    isSystem: true,
    isActive: true,
  }));

  await db.insert(categories).values([...expenseValues, ...incomeValues]);

  console.log(
    `Seeded ${expenseValues.length} expense and ${incomeValues.length} income categories.`
  );
  process.exit(0);
}

seed().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
