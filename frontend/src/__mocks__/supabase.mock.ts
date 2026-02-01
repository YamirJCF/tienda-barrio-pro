import { vi } from 'vitest'
import type { Database } from '@/types/database.types'

// Helper to create a mock query builder
const createMockQueryBuilder = (data: any = null, error: any = null) => {
    const builder = {
        select: vi.fn().mockReturnThis(),
        insert: vi.fn().mockReturnThis(),
        update: vi.fn().mockReturnThis(),
        delete: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        neq: vi.fn().mockReturnThis(),
        gt: vi.fn().mockReturnThis(),
        order: vi.fn().mockReturnThis(),
        limit: vi.fn().mockReturnThis(),
        single: vi.fn().mockReturnThis(),
        maybeSingle: vi.fn().mockReturnThis(),
        then: (resolve: any) => resolve({ data, error }),
    }
    return builder
}

// Mock auth
const mockAuth = {
    signInWithPassword: vi.fn().mockResolvedValue({ data: { session: {} }, error: null }),
    signOut: vi.fn().mockResolvedValue({ error: null }),
    getSession: vi.fn().mockResolvedValue({ data: { session: null }, error: null }),
    onAuthStateChange: vi.fn().mockReturnValue({ data: { subscription: { unsubscribe: vi.fn() } } }),
}

// Mock functions
const mockRpc = vi.fn().mockResolvedValue({ data: null, error: null })

// Main mock client
export const createMockClient = () => {
    return {
        from: vi.fn().mockReturnValue(createMockQueryBuilder([], null)),
        auth: mockAuth,
        rpc: mockRpc,
    }
}

// Global mock instance
export const supabaseMock = createMockClient()

// Helper to inject specific responses for tests
export const mockRpcResponse = (data: any, error: any = null) => {
    mockRpc.mockResolvedValueOnce({ data, error })
}

export const mockTableResponse = (data: any, error: any = null) => {
    const builder = createMockQueryBuilder(data, error)
    return builder
}
