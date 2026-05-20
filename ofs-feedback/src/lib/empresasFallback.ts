import type { Empresa } from '@/types';

export const EMPRESAS_FALLBACK: Empresa[] = [
  { id: 'a1000000-0000-0000-0000-000000000002', nome: 'Polo Norte',  cnpj: '00234567000188', ativo: true, created_at: '' },
  { id: 'a1000000-0000-0000-0000-000000000003', nome: 'G4S',         cnpj: '00345678000177', ativo: true, created_at: '' },
  { id: 'a1000000-0000-0000-0000-000000000004', nome: 'ERA',         cnpj: '00456789000166', ativo: true, created_at: '' },
  { id: 'a1000000-0000-0000-0000-000000000005', nome: 'Innovatec',   cnpj: '00567890000155', ativo: true, created_at: '' },
  { id: 'a1000000-0000-0000-0000-000000000006', nome: 'Conin',       cnpj: '00678901000144', ativo: true, created_at: '' },
  { id: 'a1000000-0000-0000-0000-000000000007', nome: 'FM',          cnpj: '00789012000133', ativo: true, created_at: '' },
  { id: 'a1000000-0000-0000-0000-000000000008', nome: 'Sodexo',      cnpj: '00890123000122', ativo: true, created_at: '' },
  { id: 'a1000000-0000-0000-0000-000000000009', nome: 'Engecom',     cnpj: '00901234000111', ativo: true, created_at: '' },
  { id: 'a1000000-0000-0000-0000-000000000010', nome: 'P&G',         cnpj: '01012345000100', ativo: true, created_at: '' },
  { id: 'a1000000-0000-0000-0000-000000000011', nome: 'Yusen',       cnpj: '01123456000199', ativo: true, created_at: '' },
  { id: 'a1000000-0000-0000-0000-000000000012', nome: 'Mainpower',   cnpj: '01234567000188', ativo: true, created_at: '' },
  { id: 'a1000000-0000-0000-0000-000000000013', nome: 'Aduana',      cnpj: '01345678000177', ativo: true, created_at: '' },
  { id: 'a1000000-0000-0000-0000-000000000014', nome: 'Prosegur',    cnpj: '01456789000166', ativo: true, created_at: '' },
];

const SECURITY_DYNAMICS_ID = 'a1000000-0000-0000-0000-000000000001';

export function filtrarEmpresasSelect(lista: Empresa[]): Empresa[] {
  const filtrada = lista.filter(
    (e) => e.id !== SECURITY_DYNAMICS_ID && e.nome?.toLowerCase() !== 'security dynamics' && e.nome?.toLowerCase() !== 'outros',
  );
  return filtrada.length > 0 ? filtrada : EMPRESAS_FALLBACK;
}
