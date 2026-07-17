import { describe, it, expect, beforeEach, vi } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import { useClientsStore } from '../../stores/clients';
import { clientRepository } from '../../data/repositories/clientRepository';
import { Decimal } from 'decimal.js';
import { type Client } from '../../types';

// Mock Client Repository
vi.mock('../../data/repositories/clientRepository', () => {
  return {
    clientRepository: {
      update: vi.fn(),
      getAll: vi.fn(),
      getById: vi.fn(),
      create: vi.fn()
    }
  };
});

describe('Clients Store - updateClient', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  it('updates a client successfully and reflects changes in store state', async () => {
    const store = useClientsStore();
    
    // Initial client state in store
    const initialClient: Client = {
      id: 'cli-001',
      name: 'Maria Perez',
      cc: '10203040',
      phone: '3001234567',
      totalDebt: new Decimal(0),
      creditLimit: new Decimal(100000),
      storeId: 'store-uuid-1'
    };
    
    store.clients = [initialClient];

    // Mock response from repository
    const updatedClient: Client = {
      ...initialClient,
      name: 'Maria Perez Updated',
      cc: '10203040',
      phone: '3009999999',
      creditLimit: new Decimal(150000)
    };

    vi.mocked(clientRepository.update).mockResolvedValue(updatedClient);

    const result = await store.updateClient('cli-001', {
      name: 'Maria Perez Updated',
      cc: '10203040',
      phone: '3009999999',
      creditLimit: new Decimal(150000)
    });

    // Assert repository update was called with correct parameters
    expect(clientRepository.update).toHaveBeenCalledWith('cli-001', {
      name: 'Maria Perez Updated',
      cc: '10203040',
      phone: '3009999999',
      creditLimit: new Decimal(150000)
    });

    // Assert client in store list was updated
    expect(result).not.toBeNull();
    expect(store.clients[0].name).toBe('Maria Perez Updated');
    expect(store.clients[0].phone).toBe('3009999999');
    expect(store.clients[0].creditLimit?.toNumber()).toBe(150000);
  });
});
