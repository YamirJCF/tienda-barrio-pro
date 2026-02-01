import { vi } from 'vitest';

export const mockSupabase = {
    from: vi.fn(),
    rpc: vi.fn(),
    auth: {
        getUser: vi.fn(),
        signInWithPassword: vi.fn(),
        signOut: vi.fn(),
    },
};

// Chainable mocks
export const mockFromReturn = {
    select: vi.fn(),
    insert: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(),
    eq: vi.fn(),
    order: vi.fn(),
    limit: vi.fn(),
    single: vi.fn(),
};

// Setup default chain
mockSupabase.from.mockReturnValue(mockFromReturn);
mockFromReturn.select.mockReturnValue(mockFromReturn);
mockFromReturn.insert.mockReturnValue(mockFromReturn);
mockFromReturn.update.mockReturnValue(mockFromReturn);
mockFromReturn.delete.mockReturnValue(mockFromReturn);
mockFromReturn.eq.mockReturnValue(mockFromReturn);
mockFromReturn.order.mockReturnValue(mockFromReturn);
mockFromReturn.limit.mockReturnValue(mockFromReturn);
mockFromReturn.single.mockReturnValue(Promise.resolve({ data: null, error: null }));
