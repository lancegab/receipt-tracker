import { Hono } from 'hono';
import auth from './auth.js';
import accounts from './accounts.js';
import transactions from './transactions.js';
import receipts from './receipts.js';
import categories from './categories.js';
import recurring from './recurring.js';
import budgets from './budgets.js';
import installments from './installments.js';
import budgetGroups from './budgetGroups.js';

const routes = new Hono();

routes.route('/auth', auth);
routes.route('/accounts', accounts);
routes.route('/transactions', transactions);
routes.route('/receipts', receipts);
routes.route('/categories', categories);
routes.route('/recurring', recurring);
routes.route('/budgets', budgets);
routes.route('/installments', installments);
routes.route('/budget-groups', budgetGroups);

export default routes;
