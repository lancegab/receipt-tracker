# Expense Tracker App — Requirements Document

**Version:** 1.0  
**Date:** February 1, 2026  
**Status:** Draft

---

## 1. Executive Summary

This document outlines the requirements for a cross-platform mobile expense tracker application. The app's core differentiator is AI-powered receipt scanning that automatically extracts and categorizes individual line items from receipt images. The application will be built using a shared codebase for iOS and Android platforms.

---

## 2. Project Overview

### 2.1 Purpose

To provide users with an intuitive expense tracking solution that minimizes manual data entry through intelligent receipt scanning while offering comprehensive financial management features including account balances and credit card tracking.

### 2.2 Target Platforms

- iOS (iPhone and iPad)
- Android (phones and tablets)

### 2.3 Technology Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| Framework | Flutter (Dart) | Single codebase for iOS/Android with native performance, rich widget library, hot reload |
| State Management | Riverpod | Type-safe, testable, compile-time checked state management |
| Navigation | GoRouter | Declarative routing with deep linking support |
| Backend | Firebase | Built-in auth, Firestore database, Cloud Storage, Cloud Functions |
| LLM Integration | OpenAI API / Claude API / Google Gemini | Receipt parsing and OCR enhancement (via Cloud Functions) |
| Local Database | Drift (SQLite) | Type-safe, reactive local persistence for offline-first |
| Image Processing | image package | Compression and manipulation before upload |
| Camera | camera + image_picker | Native camera access and gallery selection |
| Authentication | firebase_auth + google_sign_in + flutter_facebook_auth + sign_in_with_apple | Multi-provider authentication |
| HTTP Client | Dio | Robust HTTP client with interceptors, retry logic |
| Dependency Injection | get_it + injectable | Service locator pattern for clean architecture |

### 2.4 Recommended Project Structure

```
lib/
├── main.dart
├── app/
│   ├── app.dart
│   └── router.dart
├── core/
│   ├── constants/
│   ├── errors/
│   ├── extensions/
│   ├── network/
│   ├── services/
│   └── utils/
├── features/
│   ├── auth/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── accounts/
│   ├── transactions/
│   ├── receipts/
│   ├── categories/
│   └── settings/
├── shared/
│   ├── widgets/
│   └── models/
└── l10n/
```

### 2.5 Key Flutter Packages

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0
  
  # Navigation
  go_router: ^14.0.0
  
  # Firebase
  firebase_core: ^2.27.0
  firebase_auth: ^4.17.0
  cloud_firestore: ^4.15.0
  firebase_storage: ^11.6.0
  
  # Authentication
  google_sign_in: ^6.2.0
  flutter_facebook_auth: ^7.0.0
  sign_in_with_apple: ^6.1.0
  
  # Local Database
  drift: ^2.16.0
  sqlite3_flutter_libs: ^0.5.0
  
  # Networking
  dio: ^5.4.0
  
  # Image Handling
  camera: ^0.10.5
  image_picker: ^1.0.7
  image: ^4.1.0
  
  # UI Components
  flutter_svg: ^2.0.10
  cached_network_image: ^3.3.1
  shimmer: ^3.0.0
  fl_chart: ^0.67.0
  
  # Utilities
  intl: ^0.19.0
  uuid: ^4.3.0
  path_provider: ^2.1.2
  share_plus: ^8.0.0
  local_auth: ^2.2.0
  
  # Dependency Injection
  get_it: ^7.6.7
  injectable: ^2.3.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.8
  riverpod_generator: ^2.4.0
  drift_dev: ^2.16.0
  injectable_generator: ^2.4.1
  mockito: ^5.4.4
  bloc_test: ^9.1.6
  integration_test:
    sdk: flutter
```

---

## 3. Functional Requirements

### 3.1 Receipt Scanning & Processing (Core Feature)

#### 3.1.1 Image Capture

| Requirement ID | Description | Priority |
|----------------|-------------|----------|
| RS-001 | User can capture receipt image using device camera | Must Have |
| RS-002 | User can select existing image from device gallery | Must Have |
| RS-003 | App provides real-time camera preview with receipt alignment guides | Should Have |
| RS-004 | App supports multi-page receipt capture (stitch multiple images) | Could Have |

#### 3.1.2 Image Compression

| Requirement ID | Description | Priority |
|----------------|-------------|----------|
| RC-001 | Images compressed before transmission to reduce bandwidth and API costs | Must Have |
| RC-002 | Compression maintains text legibility (minimum 300 DPI equivalent) | Must Have |
| RC-003 | Target file size: ≤500KB per image (configurable) | Must Have |
| RC-004 | Supported formats: JPEG (primary), PNG, HEIC (converted to JPEG) | Must Have |
| RC-005 | Compression quality: 70-85% JPEG quality (adaptive based on image complexity) | Should Have |

**Compression Standards:**

```
Input Resolution: Up to 12MP (4000x3000)
Output Resolution: Max 2048px on longest edge
Color Space: sRGB
Format: JPEG with quality 75-85%
Max File Size: 500KB (resize if exceeded)
```

#### 3.1.3 LLM Integration for Receipt Parsing

| Requirement ID | Description | Priority |
|----------------|-------------|----------|
| LP-001 | Compressed image sent to LLM API for analysis | Must Have |
| LP-002 | LLM extracts individual line items with descriptions and prices | Must Have |
| LP-003 | LLM extracts merchant/store name | Must Have |
| LP-004 | LLM extracts transaction date | Must Have |
| LP-005 | LLM extracts subtotal, tax, and total amounts | Must Have |
| LP-006 | LLM attempts to categorize items (groceries, dining, etc.) | Should Have |
| LP-007 | LLM extracts payment method if visible | Could Have |
| LP-008 | LLM extracts store address/location | Could Have |
| LP-009 | System handles API failures gracefully with retry logic | Must Have |
| LP-010 | User can manually correct any extracted data | Must Have |

**Expected LLM Response Structure:**

```json
{
  "merchant": {
    "name": "string",
    "address": "string | null",
    "phone": "string | null"
  },
  "transaction": {
    "date": "YYYY-MM-DD",
    "time": "HH:MM | null",
    "payment_method": "string | null"
  },
  "line_items": [
    {
      "description": "string",
      "quantity": "number",
      "unit_price": "number",
      "total_price": "number",
      "category_suggestion": "string | null"
    }
  ],
  "summary": {
    "subtotal": "number",
    "tax": "number",
    "tip": "number | null",
    "total": "number"
  },
  "confidence_score": "number (0-1)"
}
```

#### 3.1.4 Entry Creation from Receipt

| Requirement ID | Description | Priority |
|----------------|-------------|----------|
| EC-001 | Each line item becomes a separate expense entry | Must Have |
| EC-002 | User can review and edit entries before saving | Must Have |
| EC-003 | User can merge or split line items | Should Have |
| EC-004 | User can delete unwanted line items | Must Have |
| EC-005 | User assigns account/credit card for the transaction | Must Have |
| EC-006 | Original receipt image stored and linked to entries | Must Have |
| EC-007 | Batch save all entries from single receipt | Must Have |

---

### 3.2 Account Management

#### 3.2.1 Account Types

| Requirement ID | Description | Priority |
|----------------|-------------|----------|
| AM-001 | User can create Cash accounts | Must Have |
| AM-002 | User can create Bank/Checking accounts | Must Have |
| AM-003 | User can create Savings accounts | Must Have |
| AM-004 | User can create Digital Wallet accounts (PayPal, Venmo, etc.) | Should Have |
| AM-005 | Each account has a name, type, currency, and current balance | Must Have |
| AM-006 | User can set initial balance when creating account | Must Have |
| AM-007 | User can archive (soft delete) accounts | Should Have |

#### 3.2.2 Balance Tracking

| Requirement ID | Description | Priority |
|----------------|-------------|----------|
| BT-001 | Account balance updates automatically based on transactions | Must Have |
| BT-002 | User can manually adjust balance with adjustment entries | Must Have |
| BT-003 | Balance history tracked over time | Should Have |
| BT-004 | Dashboard shows total balance across all accounts | Must Have |
| BT-005 | Support for multiple currencies with manual exchange rates | Could Have |

---

### 3.3 Credit Card Management

#### 3.3.1 Credit Card Setup

| Requirement ID | Description | Priority |
|----------------|-------------|----------|
| CC-001 | User can create credit card accounts | Must Have |
| CC-002 | Credit card has: name, credit limit, statement closing date, payment due date | Must Have |
| CC-003 | User can define billing cycle (e.g., closes on 15th, due on 5th of next month) | Must Have |
| CC-004 | Support for different billing cycle patterns (same month, next month) | Should Have |

#### 3.3.2 Payable Balance Tracking

| Requirement ID | Description | Priority |
|----------------|-------------|----------|
| PB-001 | Track current "payable" balance (amount owed) | Must Have |
| PB-002 | Distinguish between: current cycle charges, previous cycle balance, total balance | Must Have |
| PB-003 | Automatic calculation based on statement cutoff dates | Must Have |
| PB-004 | Show pending transactions (not yet posted) | Should Have |
| PB-005 | Display available credit (limit - current balance) | Should Have |

#### 3.3.3 Payment Recording

| Requirement ID | Description | Priority |
|----------------|-------------|----------|
| PR-001 | User can record credit card payments | Must Have |
| PR-002 | Payment reduces payable balance | Must Have |
| PR-003 | Payment linked to source account (bank account) | Must Have |
| PR-004 | Support partial payments | Must Have |
| PR-005 | Payment due date reminders/notifications | Should Have |

---

### 3.4 Manual Entry Recording

#### 3.4.1 Expense Entry

| Requirement ID | Description | Priority |
|----------------|-------------|----------|
| ME-001 | User can create expense entry with: amount, date, description, category, account | Must Have |
| ME-002 | Category selection from predefined + custom categories | Must Have |
| ME-003 | Optional: merchant name, notes, tags | Should Have |
| ME-004 | Optional: attach image or document | Should Have |
| ME-005 | Recurring expense setup (daily, weekly, monthly, yearly) | Could Have |

#### 3.4.2 Income Entry

| Requirement ID | Description | Priority |
|----------------|-------------|----------|
| IE-001 | User can record income transactions | Must Have |
| IE-002 | Income entry has: amount, date, source, category, destination account | Must Have |
| IE-003 | Recurring income setup | Could Have |

#### 3.4.3 Transfer Entry

| Requirement ID | Description | Priority |
|----------------|-------------|----------|
| TE-001 | User can record transfers between accounts | Must Have |
| TE-002 | Transfer debits source account and credits destination | Must Have |
| TE-003 | Transfer to credit card recorded as payment | Must Have |

---

### 3.5 Authentication & User Management

#### 3.5.1 Authentication Methods

| Requirement ID | Description | Priority |
|----------------|-------------|----------|
| AU-001 | Email/password registration and login | Must Have |
| AU-002 | Google OAuth authentication | Must Have |
| AU-003 | Facebook OAuth authentication | Must Have |
| AU-004 | Apple Sign-In (required for iOS App Store) | Must Have |
| AU-005 | Email verification for new accounts | Must Have |
| AU-006 | Password reset via email | Must Have |
| AU-007 | Biometric authentication (Face ID, Touch ID, Fingerprint) for app unlock | Should Have |
| AU-008 | Session management with secure token storage | Must Have |

#### 3.5.2 User Profile

| Requirement ID | Description | Priority |
|----------------|-------------|----------|
| UP-001 | User can set display name | Should Have |
| UP-002 | User can set default currency | Must Have |
| UP-003 | User can set preferred date format | Should Have |
| UP-004 | User can export all data | Should Have |
| UP-005 | User can delete account and all data | Must Have |

---

### 3.6 Categories & Organization

| Requirement ID | Description | Priority |
|----------------|-------------|----------|
| CO-001 | Predefined expense categories (Food, Transport, Shopping, Bills, etc.) | Must Have |
| CO-002 | Predefined income categories (Salary, Freelance, Investment, etc.) | Must Have |
| CO-003 | User can create custom categories | Must Have |
| CO-004 | User can edit/delete custom categories | Must Have |
| CO-005 | Categories have icons and colors | Should Have |
| CO-006 | Subcategory support | Could Have |

**Default Expense Categories:**

- Food & Dining
- Groceries
- Transportation
- Shopping
- Entertainment
- Bills & Utilities
- Healthcare
- Personal Care
- Education
- Travel
- Home
- Gifts & Donations
- Other

---

## 4. Non-Functional Requirements

### 4.1 Performance

| Requirement ID | Description | Target |
|----------------|-------------|--------|
| PF-001 | App launch time | < 2 seconds |
| PF-002 | Receipt image processing (compression + upload) | < 5 seconds |
| PF-003 | LLM response time | < 10 seconds |
| PF-004 | Screen transitions | < 300ms |
| PF-005 | Database queries | < 100ms |
| PF-006 | Offline functionality | Full read, queued writes |

### 4.2 Security

| Requirement ID | Description | Priority |
|----------------|-------------|----------|
| SE-001 | All API communications over HTTPS/TLS 1.3 | Must Have |
| SE-002 | Sensitive data encrypted at rest | Must Have |
| SE-003 | OAuth tokens stored in secure enclave/keychain | Must Have |
| SE-004 | No sensitive data in logs | Must Have |
| SE-005 | Session timeout after inactivity (configurable) | Should Have |
| SE-006 | Rate limiting on authentication endpoints | Must Have |

### 4.3 Reliability

| Requirement ID | Description | Target |
|----------------|-------------|--------|
| RE-001 | App crash rate | < 0.1% |
| RE-002 | Data sync success rate | > 99.5% |
| RE-003 | LLM API availability handling | Graceful degradation |
| RE-004 | Local data backup | Automatic daily |

### 4.4 Usability

| Requirement ID | Description | Priority |
|----------------|-------------|----------|
| US-001 | Support iOS accessibility features (VoiceOver) | Must Have |
| US-002 | Support Android accessibility features (TalkBack) | Must Have |
| US-003 | Support dynamic font sizing | Should Have |
| US-004 | Dark mode support | Should Have |
| US-005 | Onboarding tutorial for first-time users | Should Have |
| US-006 | Undo/redo for data entry | Could Have |

### 4.5 Compatibility

| Requirement ID | Description | Target |
|----------------|-------------|--------|
| CM-001 | iOS minimum version | iOS 14.0+ |
| CM-002 | Android minimum version | Android 8.0 (API 26)+ |
| CM-003 | Screen sizes | Phone and tablet |
| CM-004 | Orientations | Portrait (primary), Landscape (supported) |

---

## 5. Data Model

### 5.1 Core Entities

```
User
├── id: UUID
├── email: string
├── display_name: string
├── default_currency: string (ISO 4217)
├── created_at: timestamp
└── updated_at: timestamp

Account
├── id: UUID
├── user_id: UUID (FK)
├── name: string
├── type: enum (cash, bank, savings, wallet, credit_card)
├── currency: string (ISO 4217)
├── balance: decimal
├── credit_limit: decimal (nullable, for credit cards)
├── statement_close_day: integer (nullable, 1-31)
├── payment_due_day: integer (nullable, 1-31)
├── is_archived: boolean
├── created_at: timestamp
└── updated_at: timestamp

Transaction
├── id: UUID
├── user_id: UUID (FK)
├── account_id: UUID (FK)
├── type: enum (expense, income, transfer)
├── amount: decimal
├── date: date
├── time: time (nullable)
├── description: string
├── merchant_name: string (nullable)
├── category_id: UUID (FK)
├── notes: string (nullable)
├── receipt_id: UUID (nullable, FK)
├── transfer_account_id: UUID (nullable, FK)
├── is_pending: boolean
├── created_at: timestamp
└── updated_at: timestamp

Receipt
├── id: UUID
├── user_id: UUID (FK)
├── image_url: string
├── thumbnail_url: string
├── merchant_name: string (nullable)
├── merchant_address: string (nullable)
├── transaction_date: date
├── subtotal: decimal (nullable)
├── tax: decimal (nullable)
├── total: decimal
├── raw_llm_response: json
├── confidence_score: decimal
├── created_at: timestamp
└── updated_at: timestamp

Category
├── id: UUID
├── user_id: UUID (nullable, null = system default)
├── name: string
├── type: enum (expense, income)
├── icon: string
├── color: string (hex)
├── is_active: boolean
├── created_at: timestamp
└── updated_at: timestamp
```

### 5.2 Relationships

- User → Accounts (one-to-many)
- User → Transactions (one-to-many)
- User → Receipts (one-to-many)
- User → Categories (one-to-many, custom only)
- Account → Transactions (one-to-many)
- Receipt → Transactions (one-to-many)
- Category → Transactions (one-to-many)

---

## 6. User Interface Requirements

### 6.1 Key Screens

| Screen | Description | Priority |
|--------|-------------|----------|
| Splash/Login | Authentication options | Must Have |
| Dashboard | Account summary, recent transactions, quick actions | Must Have |
| Accounts List | All accounts with balances | Must Have |
| Account Detail | Transactions for specific account | Must Have |
| Receipt Capture | Camera/gallery with preview | Must Have |
| Receipt Review | Extracted items, edit before save | Must Have |
| Add Transaction | Manual entry form | Must Have |
| Transaction Detail | View/edit single transaction | Must Have |
| Categories | Manage expense/income categories | Must Have |
| Reports | Spending summaries, charts | Should Have |
| Settings | User preferences, data management | Must Have |
| Credit Card Detail | Billing cycle, payable balance, payments | Must Have |

### 6.2 Navigation Structure

```
Bottom Navigation
├── Home (Dashboard)
├── Transactions
├── [+] Scan Receipt / Add Entry (FAB)
├── Accounts
└── More (Settings, Reports, Categories)
```

---

## 7. Integration Requirements

### 7.1 LLM API Integration

| Requirement | Specification |
|-------------|---------------|
| Provider Options | OpenAI GPT-4 Vision, Anthropic Claude, Google Gemini |
| Authentication | API key stored securely (not in client) |
| Request Format | Base64 encoded image + structured prompt |
| Response Format | JSON with defined schema |
| Timeout | 30 seconds max |
| Retry Policy | 3 attempts with exponential backoff |
| Fallback | Manual entry if API unavailable |

### 7.2 Authentication Providers

| Provider | SDK/Method |
|----------|------------|
| Email/Password | Firebase Auth or Supabase Auth |
| Google | Google Sign-In SDK |
| Facebook | Facebook Login SDK |
| Apple | Sign in with Apple SDK |

### 7.3 Cloud Storage

| Use Case | Service |
|----------|---------|
| Receipt Images | Firebase Storage / Supabase Storage / S3 |
| Database Sync | Firestore / Supabase Realtime / Custom API |
| Backup | Automatic cloud backup with versioning |

---

## 8. Backend API Requirements

### 8.1 Technology Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| Runtime | Node.js 20+ / Bun | Modern runtime, native TypeScript support (Bun) |
| Framework | Hono | Ultrafast, lightweight, edge-ready, TypeScript-first |
| Database | MySQL 8.0+ | Reliable RDBMS, ACID compliance, JSON support |
| ORM | Drizzle ORM | Type-safe, lightweight, SQL-like syntax, excellent DX |
| Authentication | JWT (jose) | Stateless auth, edge-compatible |
| Password Hashing | bcryptjs / Bun.password | Industry standard, secure |
| Validation | Zod | TypeScript-first schema validation |
| Image Storage | AWS S3 / Cloudflare R2 | Scalable object storage, CDN-ready, presigned URLs |
| Image Processing | Sharp | Fast compression/resizing before S3 upload |
| HTTP Client | Native fetch | For LLM API calls |
| Environment | dotenv / Bun built-in | Configuration management |

### 8.2 Why This Stack?

| Choice | Rationale |
|--------|-----------|
| **Hono over Express** | 5x faster, smaller bundle, built-in TypeScript, middleware composition, edge-deployable (Cloudflare Workers, Vercel Edge) |
| **Drizzle over Prisma** | No code generation step, smaller footprint, SQL-like queries, better performance, simpler migrations |
| **S3 over local storage** | Scalable, CDN integration, presigned URLs for direct mobile upload, no server storage limits, automatic redundancy |

### 8.3 API Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter Mobile App                      │
└─────────────────────────────────────────────────────────────┘
            │                              │
            │ API Requests                 │ Direct Upload (presigned URL)
            ▼                              ▼
┌──────────────────────────┐      ┌─────────────────────────┐
│        Hono API          │      │    AWS S3 / R2          │
│  ┌────────────────────┐  │      │  (Receipt Images)       │
│  │   Routes/Handlers  │  │      └─────────────────────────┘
│  └────────────────────┘  │                 │
│           │              │                 │
│           ▼              │                 │
│  ┌────────────────────┐  │                 │
│  │  Services (LLM)    │←─┼─────────────────┘
│  └────────────────────┘  │   Fetch image for parsing
│           │              │
│           ▼              │
│  ┌────────────────────┐  │
│  │   Drizzle ORM      │  │
│  └────────────────────┘  │
└──────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────┐
│                        MySQL 8.0                             │
└─────────────────────────────────────────────────────────────┘
```

### 8.4 Project Structure

```
expense-tracker-api/
├── src/
│   ├── index.ts                 # Entry point
│   ├── app.ts                   # Hono app setup
│   ├── db/
│   │   ├── index.ts             # Drizzle client
│   │   ├── schema.ts            # Drizzle schema definitions
│   │   └── migrations/          # SQL migrations
│   ├── routes/
│   │   ├── index.ts             # Route aggregator
│   │   ├── auth.ts
│   │   ├── accounts.ts
│   │   ├── transactions.ts
│   │   ├── receipts.ts
│   │   └── categories.ts
│   ├── services/
│   │   ├── auth.service.ts
│   │   ├── llm.service.ts       # Receipt parsing
│   │   └── s3.service.ts        # S3 operations
│   ├── middleware/
│   │   ├── auth.ts
│   │   └── error.ts
│   ├── validators/              # Zod schemas
│   │   └── index.ts
│   └── types/
│       └── index.ts
├── drizzle.config.ts
├── package.json
├── tsconfig.json
└── .env.example
```

### 8.5 Database Schema (Drizzle + MySQL)

```typescript
// src/db/schema.ts
import { mysqlTable, varchar, char, decimal, boolean, 
         timestamp, date, time, text, json, mysqlEnum,
         tinyint, index } from 'drizzle-orm/mysql-core';

export const users = mysqlTable('users', {
  id: char('id', { length: 36 }).primaryKey(),
  email: varchar('email', { length: 255 }).notNull().unique(),
  passwordHash: varchar('password_hash', { length: 255 }),
  displayName: varchar('display_name', { length: 100 }),
  defaultCurrency: char('default_currency', { length: 3 }).default('USD'),
  authProvider: mysqlEnum('auth_provider', ['email', 'google', 'facebook', 'apple']).notNull(),
  authProviderId: varchar('auth_provider_id', { length: 255 }),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow().onUpdateNow(),
}, (table) => ({
  emailIdx: index('idx_email').on(table.email),
  authIdx: index('idx_auth').on(table.authProvider, table.authProviderId),
}));

export const accounts = mysqlTable('accounts', {
  id: char('id', { length: 36 }).primaryKey(),
  userId: char('user_id', { length: 36 }).notNull().references(() => users.id, { onDelete: 'cascade' }),
  name: varchar('name', { length: 100 }).notNull(),
  type: mysqlEnum('type', ['cash', 'bank', 'savings', 'wallet', 'credit_card']).notNull(),
  currency: char('currency', { length: 3 }).default('USD'),
  balance: decimal('balance', { precision: 15, scale: 2 }).default('0.00'),
  creditLimit: decimal('credit_limit', { precision: 15, scale: 2 }),
  statementCloseDay: tinyint('statement_close_day'),
  paymentDueDay: tinyint('payment_due_day'),
  isArchived: boolean('is_archived').default(false),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow().onUpdateNow(),
}, (table) => ({
  userIdx: index('idx_user_id').on(table.userId),
}));

export const categories = mysqlTable('categories', {
  id: char('id', { length: 36 }).primaryKey(),
  userId: char('user_id', { length: 36 }).references(() => users.id, { onDelete: 'cascade' }),
  name: varchar('name', { length: 50 }).notNull(),
  type: mysqlEnum('type', ['expense', 'income']).notNull(),
  icon: varchar('icon', { length: 50 }),
  color: char('color', { length: 7 }),
  isSystem: boolean('is_system').default(false),
  isActive: boolean('is_active').default(true),
  createdAt: timestamp('created_at').defaultNow(),
}, (table) => ({
  userTypeIdx: index('idx_user_type').on(table.userId, table.type),
}));

export const receipts = mysqlTable('receipts', {
  id: char('id', { length: 36 }).primaryKey(),
  userId: char('user_id', { length: 36 }).notNull().references(() => users.id, { onDelete: 'cascade' }),
  s3Key: varchar('s3_key', { length: 500 }).notNull(),
  s3ThumbnailKey: varchar('s3_thumbnail_key', { length: 500 }),
  merchantName: varchar('merchant_name', { length: 200 }),
  merchantAddress: text('merchant_address'),
  transactionDate: date('transaction_date'),
  subtotal: decimal('subtotal', { precision: 15, scale: 2 }),
  tax: decimal('tax', { precision: 15, scale: 2 }),
  total: decimal('total', { precision: 15, scale: 2 }),
  rawLlmResponse: json('raw_llm_response'),
  confidenceScore: decimal('confidence_score', { precision: 3, scale: 2 }),
  createdAt: timestamp('created_at').defaultNow(),
}, (table) => ({
  userIdx: index('idx_user_id').on(table.userId),
  dateIdx: index('idx_date').on(table.transactionDate),
}));

export const transactions = mysqlTable('transactions', {
  id: char('id', { length: 36 }).primaryKey(),
  userId: char('user_id', { length: 36 }).notNull().references(() => users.id, { onDelete: 'cascade' }),
  accountId: char('account_id', { length: 36 }).notNull().references(() => accounts.id, { onDelete: 'cascade' }),
  type: mysqlEnum('type', ['expense', 'income', 'transfer']).notNull(),
  amount: decimal('amount', { precision: 15, scale: 2 }).notNull(),
  date: date('date').notNull(),
  time: time('time'),
  description: varchar('description', { length: 255 }).notNull(),
  merchantName: varchar('merchant_name', { length: 200 }),
  categoryId: char('category_id', { length: 36 }).references(() => categories.id, { onDelete: 'set null' }),
  notes: text('notes'),
  receiptId: char('receipt_id', { length: 36 }).references(() => receipts.id, { onDelete: 'set null' }),
  transferToAccountId: char('transfer_to_account_id', { length: 36 }).references(() => accounts.id, { onDelete: 'set null' }),
  isPending: boolean('is_pending').default(false),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow().onUpdateNow(),
}, (table) => ({
  userDateIdx: index('idx_user_date').on(table.userId, table.date),
  accountIdx: index('idx_account').on(table.accountId),
  categoryIdx: index('idx_category').on(table.categoryId),
  receiptIdx: index('idx_receipt').on(table.receiptId),
}));

export const refreshTokens = mysqlTable('refresh_tokens', {
  id: char('id', { length: 36 }).primaryKey(),
  userId: char('user_id', { length: 36 }).notNull().references(() => users.id, { onDelete: 'cascade' }),
  tokenHash: varchar('token_hash', { length: 255 }).notNull(),
  expiresAt: timestamp('expires_at').notNull(),
  createdAt: timestamp('created_at').defaultNow(),
}, (table) => ({
  userIdx: index('idx_user_id').on(table.userId),
  tokenIdx: index('idx_token').on(table.tokenHash),
}));
```

### 8.6 API Endpoints

#### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Email registration |
| POST | `/api/auth/login` | Email login |
| POST | `/api/auth/google` | Google OAuth |
| POST | `/api/auth/facebook` | Facebook OAuth |
| POST | `/api/auth/apple` | Apple Sign-In |
| POST | `/api/auth/refresh` | Refresh access token |
| POST | `/api/auth/logout` | Invalidate refresh token |
| POST | `/api/auth/forgot-password` | Request password reset |
| POST | `/api/auth/reset-password` | Reset password |
| GET | `/api/auth/me` | Get current user |
| PATCH | `/api/auth/me` | Update user profile |
| DELETE | `/api/auth/me` | Delete account |

#### Accounts
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/accounts` | List all accounts |
| POST | `/api/accounts` | Create account |
| GET | `/api/accounts/:id` | Get account details |
| PATCH | `/api/accounts/:id` | Update account |
| DELETE | `/api/accounts/:id` | Archive account |
| GET | `/api/accounts/:id/transactions` | Get account transactions |

#### Transactions
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/transactions` | List transactions (with filters) |
| POST | `/api/transactions` | Create transaction |
| POST | `/api/transactions/batch` | Create multiple transactions |
| GET | `/api/transactions/:id` | Get transaction details |
| PATCH | `/api/transactions/:id` | Update transaction |
| DELETE | `/api/transactions/:id` | Delete transaction |

#### Receipts
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/receipts/presigned-url` | Get S3 presigned URL for upload |
| POST | `/api/receipts/process` | Parse uploaded receipt via LLM |
| GET | `/api/receipts` | List receipts |
| GET | `/api/receipts/:id` | Get receipt details |
| GET | `/api/receipts/:id/image-url` | Get presigned URL for viewing |
| DELETE | `/api/receipts/:id` | Delete receipt |

#### Categories
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/categories` | List categories |
| POST | `/api/categories` | Create custom category |
| PATCH | `/api/categories/:id` | Update category |
| DELETE | `/api/categories/:id` | Delete custom category |

### 8.7 S3 Upload Flow

```
┌─────────────┐     1. Request presigned URL      ┌─────────────┐
│   Flutter   │ ─────────────────────────────────→│   Hono API  │
│     App     │                                   │             │
│             │←──────────────────────────────────│             │
└─────────────┘     2. Return presigned URL       └─────────────┘
      │                     + s3Key                      
      │                                                  
      │ 3. Direct upload to S3                          
      │    (PUT with presigned URL)                     
      ▼                                                  
┌─────────────┐                                   ┌─────────────┐
│   AWS S3    │                                   │   Hono API  │
│             │                                   │             │
└─────────────┘                                   └─────────────┘
      │                                                  ▲
      │                                                  │
      └──────────────────────────────────────────────────┘
              4. POST /receipts/process { s3Key }
              5. API fetches image, sends to LLM
              6. Returns parsed data
```

### 8.8 Request/Response Examples

#### Get Presigned Upload URL
```
GET /api/receipts/presigned-url?filename=receipt.jpg&contentType=image/jpeg
Authorization: Bearer <access_token>

Response 200:
{
  "success": true,
  "data": {
    "uploadUrl": "https://bucket.s3.amazonaws.com/receipts/abc123.jpg?X-Amz-...",
    "s3Key": "receipts/user-id/abc123.jpg",
    "expiresIn": 300
  }
}
```

#### Process Uploaded Receipt
```
POST /api/receipts/process
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "s3Key": "receipts/user-id/abc123.jpg",
  "accountId": "550e8400-e29b-41d4-a716-446655440001"
}

Response 201:
{
  "success": true,
  "data": {
    "receipt": {
      "id": "550e8400-e29b-41d4-a716-446655440002",
      "merchantName": "Walmart",
      "transactionDate": "2026-02-01",
      "total": 45.67,
      "confidenceScore": 0.92,
      "imageUrl": "https://cdn.example.com/receipts/..."
    },
    "lineItems": [
      {
        "description": "Milk 1 Gallon",
        "quantity": 1,
        "unitPrice": 3.99,
        "totalPrice": 3.99,
        "categorySuggestion": "groceries"
      }
    ]
  }
}
```

### 8.9 Environment Variables

```env
# Server
PORT=3000
NODE_ENV=development

# Database
DATABASE_URL=mysql://user:password@localhost:3306/expense_tracker

# JWT
JWT_SECRET=your-256-bit-secret
JWT_ACCESS_EXPIRES=15m
JWT_REFRESH_EXPIRES=7d

# OAuth
GOOGLE_CLIENT_ID=your-google-client-id
FACEBOOK_APP_ID=your-facebook-app-id
APPLE_TEAM_ID=your-apple-team-id

# AWS S3
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
S3_BUCKET=expense-tracker-receipts
S3_PRESIGNED_EXPIRES=300

# Or Cloudflare R2 (S3-compatible)
# R2_ACCOUNT_ID=your-account-id
# R2_ACCESS_KEY_ID=your-r2-key
# R2_SECRET_ACCESS_KEY=your-r2-secret
# R2_BUCKET=expense-tracker-receipts

# LLM API
OPENAI_API_KEY=sk-...
LLM_MODEL=gpt-4o
```

### 8.10 Dependencies

```json
{
  "dependencies": {
    "hono": "^4.0.0",
    "@hono/zod-validator": "^0.2.0",
    "drizzle-orm": "^0.29.0",
    "mysql2": "^3.9.1",
    "zod": "^3.22.0",
    "jose": "^5.2.0",
    "bcryptjs": "^2.4.3",
    "@aws-sdk/client-s3": "^3.500.0",
    "@aws-sdk/s3-request-presigner": "^3.500.0",
    "sharp": "^0.33.2",
    "uuid": "^9.0.1"
  },
  "devDependencies": {
    "typescript": "^5.3.0",
    "drizzle-kit": "^0.20.0",
    "@types/node": "^20.11.0",
    "@types/bcryptjs": "^2.4.6"
  }
}
```

### 8.11 Security Requirements

| Requirement | Implementation |
|-------------|----------------|
| Password Storage | bcrypt with cost factor 12 |
| JWT Signing | HS256 (jose library, edge-compatible) |
| Token Storage | Access token (15min), Refresh token (DB stored, rotated) |
| Rate Limiting | Hono middleware, 100 req/min per IP |
| Input Validation | Zod schemas on all endpoints |
| SQL Injection | Drizzle parameterized queries |
| S3 Security | Presigned URLs (short TTL), private bucket |
| HTTPS | Required in production |
| CORS | Hono cors middleware, whitelist origins |

---

## 9. Testing Requirements

| Test Type | Coverage Target | Tools |
|-----------|-----------------|-------|
| Unit Tests | 80% code coverage | flutter_test, mockito |
| Widget Tests | All custom widgets | flutter_test |
| Integration Tests | Critical paths | integration_test package |
| E2E Tests | Core user flows | patrol / maestro |
| Performance Tests | Key metrics | Flutter DevTools, custom profiling |
| Security Tests | OWASP Mobile Top 10 | Manual + automated scans |

### 8.1 Testing Strategy

```dart
// Example unit test for receipt compression
void main() {
  group('ImageCompressionService', () {
    late ImageCompressionService service;
    
    setUp(() {
      service = ImageCompressionService();
    });
    
    test('compresses image below 500KB threshold', () async {
      final largeImage = await loadTestImage('large_receipt.jpg');
      final compressed = await service.compress(largeImage);
      
      expect(compressed.lengthInBytes, lessThan(500 * 1024));
    });
    
    test('maintains minimum quality for OCR', () async {
      final image = await loadTestImage('receipt.jpg');
      final compressed = await service.compress(image);
      
      expect(compressed.width, lessThanOrEqualTo(2048));
      expect(compressed.height, lessThanOrEqualTo(2048));
    });
  });
}
```

### 8.2 CI/CD Pipeline

```yaml
# .github/workflows/flutter_ci.yml
name: Flutter CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage
      - run: flutter build apk --debug
      - run: flutter build ios --debug --no-codesign
```

---

## 10. Release Requirements

### 9.1 App Store Requirements

| Platform | Requirements |
|----------|--------------|
| iOS | Apple Developer Account, App Store guidelines compliance, Privacy labels |
| Android | Google Play Developer Account, Play Store policies compliance, Data safety form |

### 9.2 Privacy & Compliance

- Privacy Policy (required)
- Terms of Service (required)
- GDPR compliance for EU users
- CCPA compliance for California users
- Data export functionality
- Account deletion functionality

---

## 11. Future Considerations (Out of Scope for V1)

- Bank account sync via Plaid/Yodlee
- Budget creation and tracking
- Bill reminders and scheduling
- Multi-user/family sharing
- Receipt email forwarding integration
- Mileage tracking
- Investment account tracking
- Tax report generation
- AI-powered spending insights
- Voice entry via assistant integration

---

## 12. Glossary

| Term | Definition |
|------|------------|
| Line Item | Individual product/service on a receipt |
| Payable Balance | Amount owed on a credit card |
| Statement Closing Date | Day when billing cycle ends and statement is generated |
| Payment Due Date | Deadline for paying the statement balance |
| LLM | Large Language Model (AI for receipt parsing) |
| OCR | Optical Character Recognition |

---

## 13. Appendix

### A. Image Compression Implementation (Flutter/Dart)

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImageCompressionService {
  static const int maxDimension = 2048;
  static const int maxFileSizeBytes = 500 * 1024; // 500KB
  static const int initialQuality = 85;
  static const int minQuality = 60;

  Future<Uint8List> compressReceiptImage(File imageFile) async {
    // Read image bytes
    final bytes = await imageFile.readAsBytes();
    
    // Decode image
    img.Image? image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }
    
    // Step 1: Resize if needed
    if (image.width > maxDimension || image.height > maxDimension) {
      image = img.copyResize(
        image,
        width: image.width > image.height ? maxDimension : null,
        height: image.height >= image.width ? maxDimension : null,
        interpolation: img.Interpolation.linear,
      );
    }
    
    // Step 2: Compress with quality adjustment
    int quality = initialQuality;
    Uint8List compressed = Uint8List.fromList(
      img.encodeJpg(image, quality: quality),
    );
    
    // Step 3: Reduce quality if over size limit
    while (compressed.length > maxFileSizeBytes && quality > minQuality) {
      quality -= 5;
      compressed = Uint8List.fromList(
        img.encodeJpg(image, quality: quality),
      );
    }
    
    return compressed;
  }
}
```

### B. LLM Service Implementation (Flutter/Dart)

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

class ReceiptParsingService {
  final Dio _dio;
  final String _apiKey;
  final String _baseUrl;

  ReceiptParsingService({
    required String apiKey,
    String baseUrl = 'https://api.openai.com/v1',
  })  : _apiKey = apiKey,
        _baseUrl = baseUrl,
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ));

  Future<ParsedReceipt> parseReceipt(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);
    
    final response = await _dio.post(
      '$_baseUrl/chat/completions',
      options: Options(
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'model': 'gpt-4o',
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': _buildPrompt(),
              },
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,$base64Image',
                },
              },
            ],
          },
        ],
        'max_tokens': 2000,
        'response_format': {'type': 'json_object'},
      },
    );

    final content = response.data['choices'][0]['message']['content'];
    return ParsedReceipt.fromJson(jsonDecode(content));
  }

  String _buildPrompt() {
    return '''
You are a receipt parser. Analyze this receipt image and extract:

1. Merchant information (name, address if visible)
2. Transaction date and time
3. All line items with:
   - Item description
   - Quantity
   - Unit price
   - Total price
   - Suggested category (one of: food_dining, groceries, transportation, shopping, entertainment, bills_utilities, healthcare, personal_care, education, travel, home, gifts_donations, other)
4. Subtotal, tax, and total amounts
5. Payment method if visible

Respond in the following JSON format:
{
  "merchant": {
    "name": "string",
    "address": "string | null"
  },
  "transaction": {
    "date": "YYYY-MM-DD",
    "time": "HH:MM | null",
    "payment_method": "string | null"
  },
  "line_items": [
    {
      "description": "string",
      "quantity": number,
      "unit_price": number,
      "total_price": number,
      "category_suggestion": "string"
    }
  ],
  "summary": {
    "subtotal": number | null,
    "tax": number | null,
    "total": number
  },
  "confidence_score": number
}

If any field is unclear or not visible, use null.
Provide a confidence score (0.0-1.0) for the overall extraction quality.
''';
  }
}
```

### C. Data Models (Flutter/Dart)

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';
part 'models.g.dart';

@freezed
class ParsedReceipt with _$ParsedReceipt {
  const factory ParsedReceipt({
    required Merchant merchant,
    required Transaction transaction,
    required List<LineItem> lineItems,
    required ReceiptSummary summary,
    required double confidenceScore,
  }) = _ParsedReceipt;

  factory ParsedReceipt.fromJson(Map<String, dynamic> json) =>
      _$ParsedReceiptFromJson(json);
}

@freezed
class Merchant with _$Merchant {
  const factory Merchant({
    required String name,
    String? address,
    String? phone,
  }) = _Merchant;

  factory Merchant.fromJson(Map<String, dynamic> json) =>
      _$MerchantFromJson(json);
}

@freezed
class LineItem with _$LineItem {
  const factory LineItem({
    required String description,
    required double quantity,
    required double unitPrice,
    required double totalPrice,
    String? categorySuggestion,
  }) = _LineItem;

  factory LineItem.fromJson(Map<String, dynamic> json) =>
      _$LineItemFromJson(json);
}

@freezed
class Account with _$Account {
  const factory Account({
    required String id,
    required String userId,
    required String name,
    required AccountType type,
    required String currency,
    required double balance,
    double? creditLimit,
    int? statementCloseDay,
    int? paymentDueDay,
    @Default(false) bool isArchived,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Account;

  factory Account.fromJson(Map<String, dynamic> json) =>
      _$AccountFromJson(json);
}

enum AccountType {
  cash,
  bank,
  savings,
  wallet,
  creditCard,
}
```

### D. Riverpod State Management Example

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'accounts_provider.g.dart';

@riverpod
class AccountsNotifier extends _$AccountsNotifier {
  @override
  Future<List<Account>> build() async {
    return ref.read(accountRepositoryProvider).getAccounts();
  }

  Future<void> addAccount(Account account) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(accountRepositoryProvider).createAccount(account);
      return ref.read(accountRepositoryProvider).getAccounts();
    });
  }

  Future<void> updateBalance(String accountId, double amount) async {
    state = await AsyncValue.guard(() async {
      await ref.read(accountRepositoryProvider).updateBalance(accountId, amount);
      return ref.read(accountRepositoryProvider).getAccounts();
    });
  }
}

@riverpod
double totalBalance(TotalBalanceRef ref) {
  final accounts = ref.watch(accountsNotifierProvider);
  return accounts.maybeWhen(
    data: (list) => list
        .where((a) => a.type != AccountType.creditCard && !a.isArchived)
        .fold(0.0, (sum, a) => sum + a.balance),
    orElse: () => 0.0,
  );
}

@riverpod
double totalCreditCardPayable(TotalCreditCardPayableRef ref) {
  final accounts = ref.watch(accountsNotifierProvider);
  return accounts.maybeWhen(
    data: (list) => list
        .where((a) => a.type == AccountType.creditCard && !a.isArchived)
        .fold(0.0, (sum, a) => sum + a.balance.abs()),
    orElse: () => 0.0,
  );
}
```

### E. Authentication Service (Flutter/Dart)

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // Email/Password
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Google Sign-In
  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign in cancelled');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  // Facebook Sign-In
  Future<UserCredential> signInWithFacebook() async {
    final result = await FacebookAuth.instance.login();
    if (result.status != LoginStatus.success) {
      throw Exception('Facebook sign in failed: ${result.status}');
    }

    final credential = FacebookAuthProvider.credential(
      result.accessToken!.tokenString,
    );
    return await _auth.signInWithCredential(credential);
  }

  // Apple Sign-In
  Future<UserCredential> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    return await _auth.signInWithCredential(oauthCredential);
  }

  // Sign Out
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
      FacebookAuth.instance.logOut(),
    ]);
  }

  // Password Reset
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
```

---

*Document maintained by: [Product Team]*  
*Last updated: February 1, 2026*
