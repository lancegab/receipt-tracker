export default {
  schema: './src/db/schema.ts',
  out: './src/db/migrations',
  dialect: 'mysql' as const,
  dbCredentials: {
    url: process.env.DATABASE_URL!,
  },
};
