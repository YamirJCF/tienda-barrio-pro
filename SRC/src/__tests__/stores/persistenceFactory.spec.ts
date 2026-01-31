import { describe, it, expect } from 'vitest';
import { employeeRepository } from '../../data/repositories/employeeRepository';
import { clientRepository } from '../../data/repositories/clientRepository';

describe('Persistence Layer Factory', () => {
    it('should successfully instantiate employeeRepository', () => {
        expect(employeeRepository).toBeDefined();
        // Check for essential methods
        expect(employeeRepository.create).toBeDefined();
        expect(employeeRepository.validatePin).toBeDefined();
    });

    it('should successfully instantiate clientRepository', () => {
        expect(clientRepository).toBeDefined();
        expect(clientRepository.getAll).toBeDefined();
        expect(clientRepository.create).toBeDefined();
        expect(clientRepository.getTransactions).toBeDefined();
    });
});
