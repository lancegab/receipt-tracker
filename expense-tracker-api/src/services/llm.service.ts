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
  const model = process.env.LLM_MODEL || 'gpt-4o';
  const apiKey = process.env.OPENAI_API_KEY;

  if (!apiKey) {
    throw new Error('OPENAI_API_KEY is not configured');
  }

  let lastError: Error | null = null;

  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      const response = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model,
          messages: [
            {
              role: 'user',
              content: [
                { type: 'text', text: LLM_PROMPT },
                {
                  type: 'image_url',
                  image_url: {
                    url: `data:${contentType};base64,${base64Image}`,
                  },
                },
              ],
            },
          ],
          max_tokens: 2000,
          response_format: { type: 'json_object' },
        }),
        signal: AbortSignal.timeout(30000),
      });

      if (!response.ok) {
        const errorBody = await response.text();
        throw new Error(`LLM API error (${response.status}): ${errorBody}`);
      }

      const data = await response.json() as {
        choices: Array<{ message: { content: string } }>;
      };
      const content = data.choices[0]?.message?.content;

      if (!content) {
        throw new Error('Empty response from LLM API');
      }

      return JSON.parse(content) as LLMParsedReceipt;
    } catch (err) {
      lastError = err as Error;
      if (attempt < MAX_RETRIES) {
        await sleep(RETRY_DELAY_MS * Math.pow(2, attempt - 1));
      }
    }
  }

  throw new Error(
    `Failed to parse receipt after ${MAX_RETRIES} attempts: ${lastError?.message}`
  );
}
