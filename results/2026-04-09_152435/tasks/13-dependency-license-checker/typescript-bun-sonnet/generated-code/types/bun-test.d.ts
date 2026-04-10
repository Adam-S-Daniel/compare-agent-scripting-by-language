// Ambient type declarations for Bun's built-in test runner module.
// Allows tsc to understand "bun:test" imports without requiring @types/bun.

declare module "bun:test" {
  export function describe(label: string, fn: () => void): void;
  export function test(label: string, fn: () => void | Promise<void>): void;
  export function it(label: string, fn: () => void | Promise<void>): void;
  export function beforeAll(fn: () => void | Promise<void>): void;
  export function afterAll(fn: () => void | Promise<void>): void;
  export function beforeEach(fn: () => void | Promise<void>): void;
  export function afterEach(fn: () => void | Promise<void>): void;
  export function expect(value: unknown): Matchers;
  export function mock<T extends (...args: unknown[]) => unknown>(fn?: T): T & { mock: { calls: unknown[][] } };
  export function spyOn(object: Record<string, unknown>, method: string): unknown;

  interface Matchers {
    toBe(expected: unknown): void;
    toEqual(expected: unknown): void;
    toStrictEqual(expected: unknown): void;
    toContain(expected: unknown): void;
    toHaveLength(expected: number): void;
    toBeTruthy(): void;
    toBeFalsy(): void;
    toBeNull(): void;
    toBeUndefined(): void;
    toThrow(message?: string | RegExp): void;
    not: Matchers;
    resolves: Matchers;
    rejects: Matchers;
  }
}
