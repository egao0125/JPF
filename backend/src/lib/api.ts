import { NextResponse } from "next/server";
import { ZodSchema, ZodError } from "zod";

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

export function ok(data: unknown, status = 200) {
  return NextResponse.json(data, { status });
}

// Wraps a route handler: catches ApiError/ZodError into clean JSON errors.
export function handler<T extends unknown[]>(
  fn: (...args: T) => Promise<NextResponse>
): (...args: T) => Promise<NextResponse> {
  return async (...args: T) => {
    try {
      return await fn(...args);
    } catch (e) {
      if (e instanceof ApiError) {
        return NextResponse.json({ error: e.message }, { status: e.status });
      }
      if (e instanceof ZodError) {
        return NextResponse.json(
          { error: "入力内容が正しくありません", details: e.flatten() },
          { status: 400 }
        );
      }
      console.error(e);
      return NextResponse.json({ error: "サーバーエラーが発生しました" }, { status: 500 });
    }
  };
}

export async function parseBody<T>(req: Request, schema: ZodSchema<T>): Promise<T> {
  let json: unknown;
  try {
    json = await req.json();
  } catch {
    throw new ApiError(400, "JSONの形式が正しくありません");
  }
  return schema.parse(json);
}
