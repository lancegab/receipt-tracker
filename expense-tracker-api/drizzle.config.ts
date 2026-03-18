export default {
  schema: './src/db/schema.ts',
  out: './src/db/migrations',
  driver: 'mysql2' as const,
  dbCredentials: {
    uri: process.env.DATABASE_URL!,
  },
};
