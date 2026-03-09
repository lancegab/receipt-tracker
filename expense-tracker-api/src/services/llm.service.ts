import type { LLMParsedReceipt } from '../types/index.js';

const LLM_PROMPT = `You are a receipt parser. Analyze this receipt image and extract:

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
Provide a confidence score (0.0-1.0) for the overall extraction quality.`;

const MAX_RETRIES = 3;
const RETRY_DELAY_MS = 1000;

async function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export async function parseReceiptImage(
  imageBuffer: Buffer,
  contentType: string = 'image/jpeg'
): Promise<LLMParsedReceipt> {
  const base64Image = imageBuffer.toString('base64');
  const geminiKey = process.env.GEMINI_API_KEY;
  const model = process.env.LLM_MODEL || 'gemini-3.0-flash';

  if (!geminiKey) {
    throw new Error('GEMINI_API_KEY is not configured');
  }

  // Map MIME type to Gemini format
  const mimeType = contentType || 'image/jpeg';

  let lastError: Error | null = null;

  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${geminiKey}`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            contents: [
              {
                parts: [
                  { text: LLM_PROMPT },
                  {
                    inlineData: {
                      mimeType,
                      data: base64Image,
                    },
                  },
                ],
              },
            ],
            generationConfig: {
              responseMimeType: 'application/json',
              maxOutputTokens: 2000,
            },
          }),
          signal: AbortSignal.timeout(30000),
        }
      );

      if (!response.ok) {
        const errorBody = await response.text();
        const err = new Error(`Gemini API error (${response.status}): ${errorBody}`);
        // Don't retry on quota/auth errors
        if (response.status === 429 || response.status === 401 || response.status === 403) {
          throw Object.assign(err, { noRetry: true });
        }
        throw err;
      }

      const data = (await response.json()) as {
        candidates: Array<{
          content: { parts: Array<{ text: string }> };
        }>;
      };

      const content = data.candidates?.[0]?.content?.parts?.[0]?.text;

      if (!content) {
        throw new Error('Empty response from Gemini API');
      }

      return JSON.parse(content) as LLMParsedReceipt;
    } catch (err) {
      lastError = err as Error;
      if ((err as any).noRetry) break;
      if (attempt < MAX_RETRIES) {
        await sleep(RETRY_DELAY_MS * Math.pow(2, attempt - 1));
      }
    }
  }

  throw new Error(
    `Failed to parse receipt after ${MAX_RETRIES} attempts: ${lastError?.message}`
  );
}
