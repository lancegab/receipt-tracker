export interface JWTPayload {
  sub: string;
  email: string;
  iat?: number;
  exp?: number;
}

export interface AuthUser {
  id: string;
  email: string;
}

export interface LLMParsedReceipt {
  merchant: {
    name: string;
    address: string | null;
    phone?: string | null;
  };
  transaction: {
    date: string;
    time: string | null;
    payment_method: string | null;
  };
  line_items: LLMLineItem[];
  summary: {
    subtotal: number | null;
    tax: number | null;
    tip?: number | null;
    total: number;
  };
  confidence_score: number;
}

export interface LLMLineItem {
  description: string;
  quantity: number;
  unit_price: number;
  total_price: number;
  category_suggestion: string | null;
}

export interface PaginationParams {
  page: number;
  limit: number;
}

export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
  meta?: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}
