import { Hono } from 'hono';
import auth from './auth.js';
import accounts from './accounts.js';
import transactions from './transactions.js';
import receipts from './receipts.js';
import categories from './categories.js';

const routes = new Hono();

routes.route('/auth', auth);
routes.route('/accounts', accounts);
routes.route('/transactions', transactions);
routes.route('/receipts', receipts);
routes.route('/categories', categories);

export default routes;
