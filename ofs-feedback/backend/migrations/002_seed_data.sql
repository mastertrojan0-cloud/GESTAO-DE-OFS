-- ============================================================================
-- MIGRATION 002: SEED DATA — DADOS INICIAIS E DE TESTE
-- PostgreSQL 16 | Desenvolvimento / Homologação
-- Security Dynamics | 2026-05-13
-- ============================================================================
-- ⚠️ AMBIENTE: DESENVOLVIMENTO / HOMOLOGAÇÃO
-- ⚠️ NÃO EXECUTAR EM PRODUÇÃO sem alterar senhas
-- ============================================================================

-- ============================================================================
-- SEÇÃO A: 15 EMPRESAS
-- ============================================================================

INSERT INTO empresas (id, nome, cnpj, is_custom, ativo) VALUES
    ('a1000000-0000-0000-0000-000000000001', 'Security Dynamics', '00123456000199', FALSE, TRUE),
    ('a1000000-0000-0000-0000-000000000002', 'Polo Norte',        '00234567000188', FALSE, TRUE),
    ('a1000000-0000-0000-0000-000000000003', 'G4S',               '00345678000177', FALSE, TRUE),
    ('a1000000-0000-0000-0000-000000000004', 'ERA',               '00456789000166', FALSE, TRUE),
    ('a1000000-0000-0000-0000-000000000005', 'Innovatec',         '00567890000155', FALSE, TRUE),
    ('a1000000-0000-0000-0000-000000000006', 'Conin',             '00678901000144', FALSE, TRUE),
    ('a1000000-0000-0000-0000-000000000007', 'FM',                '00789012000133', FALSE, TRUE),
    ('a1000000-0000-0000-0000-000000000008', 'Sodexo',            '00890123000122', FALSE, TRUE),
    ('a1000000-0000-0000-0000-000000000009', 'Engecom',           '00901234000111', FALSE, TRUE),
    ('a1000000-0000-0000-0000-000000000010', 'P&G',               '01012345000100', FALSE, TRUE),
    ('a1000000-0000-0000-0000-000000000011', 'Yusen',             '01123456000199', FALSE, TRUE),
    ('a1000000-0000-0000-0000-000000000012', 'Mainpower',         '01234567000188', FALSE, TRUE),
    ('a1000000-0000-0000-0000-000000000013', 'Aduana',            '01345678000177', FALSE, TRUE),
    ('a1000000-0000-0000-0000-000000000014', 'Prosegur',          '01456789000166', FALSE, TRUE),
    ('a1000000-0000-0000-0000-000000000015', 'Outros',            NULL,               TRUE,  TRUE)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- SEÇÃO B: CONTRATO PADRÃO
-- ============================================================================

INSERT INTO contratos (id, empresa_id, nome, descricao) VALUES
    ('f1000000-0000-0000-0000-000000000001',
     'a1000000-0000-0000-0000-000000000001',
     'Operação Security Dynamics',
     'Contrato principal de operações — Fiscalização e Feedback Comportamental')
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- SEÇÃO C: USUÁRIO ADMINISTRADOR
-- ============================================================================
-- Senha: Admin@123 (bcrypt cost 12)

INSERT INTO usuarios (id, username, password_hash, nome, email, perfil,
                      empresa_id, empresa_nome, password_changed_at)
VALUES (
    'd1000000-0000-0000-0000-000000000001',
    'admin',
    '$2b$12$5.eK8RXhxYcPoMt/nTIcvuogbt/J45zl/sjVgFSCDRsgc1o8k0d92',
    'Administrador do Sistema',
    'admin@securitydynamics.com.br',
    'admin',
    'a1000000-0000-0000-0000-000000000001',
    'Security Dynamics',
    NOW()
)
ON CONFLICT (id) DO NOTHING;

-- Registra senha inicial no histórico (anti-reuso)
INSERT INTO password_history (user_id, password_hash)
SELECT id, password_hash
FROM usuarios
WHERE username = 'admin'
  AND NOT EXISTS (
      SELECT 1 FROM password_history ph WHERE ph.user_id = usuarios.id
  );

-- ============================================================================
-- SEÇÃO D: USUÁRIOS DE TESTE (5 usuários — 1 por perfil + 1 extra)
-- ============================================================================
-- Senha padrão: Senha@123 (bcrypt cost 12)

INSERT INTO usuarios (id, username, password_hash, nome, email, perfil,
                      empresa_id, empresa_nome, password_changed_at) VALUES
    -- Gestor
    ('d1000000-0000-0000-0000-000000000005',
     'gestor.sd',
     '$2b$12$jWkk5gOZl2C92Cq9G9ekH.g6/.uwVIy1PdIdW3rOfJ9cbCwmzMB36',
     'Carlos Gestor',
     'gestor@securitydynamics.com.br',
     'gestor',
     'a1000000-0000-0000-0000-000000000001',
     'Security Dynamics',
     NOW()),
    -- Supervisor 1
    ('d1000000-0000-0000-0000-000000000006',
     'supervisor.joao',
     '$2b$12$jWkk5gOZl2C92Cq9G9ekH.g6/.uwVIy1PdIdW3rOfJ9cbCwmzMB36',
     'João Silva',
     'joao.silva@securitydynamics.com.br',
     'supervisor',
     'a1000000-0000-0000-0000-000000000001',
     'Security Dynamics',
     NOW()),
    -- Supervisor 2 (extra)
    ('d1000000-0000-0000-0000-000000000007',
     'supervisor.maria',
     '$2b$12$jWkk5gOZl2C92Cq9G9ekH.g6/.uwVIy1PdIdW3rOfJ9cbCwmzMB36',
     'Maria Oliveira',
     'maria.oliveira@securitydynamics.com.br',
     'supervisor',
     'a1000000-0000-0000-0000-000000000001',
     'Security Dynamics',
     NOW()),
    -- Observador 1
    ('d1000000-0000-0000-0000-000000000008',
     'observador.pedro',
     '$2b$12$jWkk5gOZl2C92Cq9G9ekH.g6/.uwVIy1PdIdW3rOfJ9cbCwmzMB36',
     'Pedro Santos',
     'pedro.santos@securitydynamics.com.br',
     'observador',
     'a1000000-0000-0000-0000-000000000001',
     'Security Dynamics',
     NOW()),
    -- Observador 2
    ('d1000000-0000-0000-0000-000000000009',
     'observador.ana',
     '$2b$12$jWkk5gOZl2C92Cq9G9ekH.g6/.uwVIy1PdIdW3rOfJ9cbCwmzMB36',
     'Ana Costa',
     'ana.costa@securitydynamics.com.br',
     'observador',
     'a1000000-0000-0000-0000-000000000001',
     'Security Dynamics',
     NOW())
ON CONFLICT (id) DO NOTHING;

-- Registra senhas iniciais no histórico
INSERT INTO password_history (user_id, password_hash)
SELECT id, password_hash
FROM usuarios
WHERE id IN (
    'd1000000-0000-0000-0000-000000000005',
    'd1000000-0000-0000-0000-000000000006',
    'd1000000-0000-0000-0000-0000-000000000007',
    'd1000000-0000-0000-0000-000000000008',
    'd1000000-0000-0000-0000-000000000009'
)
  AND NOT EXISTS (
      SELECT 1 FROM password_history ph WHERE ph.user_id = usuarios.id
  );

-- ============================================================================
-- SEÇÃO E: PARÂMETROS DO SISTEMA
-- ============================================================================

INSERT INTO system_params (id, chave, valor, descricao) VALUES
    ('s1000000-0000-0000-0000-000000000001',
     'nome_sistema',
     'Sistema de Feedback Comportamental OFS/OFS',
     'Nome exibido no cabeçalho da aplicação'),
    ('s1000000-0000-0000-0000-000000000002',
     'tempo_sessao_minutos',
     '15',
     'Tempo de expiração do token de acesso em minutos'),
    ('s1000000-0000-0000-0000-000000000003',
     'meta_padrao_ofc_por_pessoa',
     '5',
     'Meta diária padrão de OFS por pessoa'),
    ('s1000000-0000-0000-0000-000000000004',
     'tempo_sessao_refresh_horas',
     '8',
     'Tempo de expiração do refresh token em horas'),
    ('s1000000-0000-0000-0000-000000000005',
     'max_tentativas_login',
     '5',
     'Número máximo de tentativas de login antes do bloqueio'),
    ('s1000000-0000-0000-0000-000000000006',
     'tempo_bloqueio_minutos',
     '30',
     'Tempo de bloqueio da conta após exceder tentativas de login'),
    ('s1000000-0000-0000-0000-000000000007',
     'versao_sistema',
     '1.0.0',
     'Versão atual do sistema')
ON CONFLICT (id) DO NOTHING;

-- app_state inicial
INSERT INTO app_state (key, value) VALUES
    ('maintenance_mode', 'false'),
    ('system_version', '1.0.0')
ON CONFLICT (key) DO NOTHING;

-- ============================================================================
-- SEÇÃO F: META INICIAL (SEMANA ATUAL)
-- ============================================================================

INSERT INTO metas (id, empresa_id, contrato_id, pessoas_ativas, meta_diaria,
                   meta_semanal, usuarios_ativos, vigencia_inicio)
VALUES (
    'g1000000-0000-0000-0000-000000000001',
    'a1000000-0000-0000-0000-000000000001',        -- Security Dynamics
    'f1000000-0000-0000-0000-000000000001',        -- Contrato padrão
    50,                                             -- 50 pessoas ativas
    5,                                              -- meta diária por pessoa (5 OFSS/dia)
    5,                                              -- meta semanal
    10,                                             -- 10 usuários ativos (observadores)
    date_trunc('week', CURRENT_DATE)::date          -- início = segunda-feira da semana atual
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- SEÇÃO G: 50 OFSS DE EXEMPLO (4 semanas)
-- ============================================================================
-- Distribuídos entre 30/04/2026 e 28/05/2026
-- Mix de positivo/negativo, várias empresas, turnos variados

INSERT INTO OFSS (id, data, hora, usuario_gerador_id, usuario_gerador_nome,
    usuario_gerador_email, usuario_gerador_perfil, usuario_gerador_empresa_nome,
    codigo, nome_observado, atividade, local, empresa_id, empresa_nome,
    contrato_id, contrato_nome, turno, tipo, comportamento, observacao, status,
    created_at, updated_at)
VALUES
-- ====== Semana 1: 28/04 a 04/05 (semana 18) ======
('e0000000-0000-0000-0000-000000000001',
 '2026-04-30', '08:15', 'd1000000-0000-0000-0000-000000000008',
 'Pedro Santos', 'pedro.santos@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-18-0001', 'Trabalhador Alpha',
 'Operação de empilhadeira no galpão A', 'Galpão A — Corredor 3',
 'a1000000-0000-0000-0000-000000000001', 'Security Dynamics',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Trabalhador utilizando todos os EPIs corretamente e sinalizando manobras com buzina conforme procedimento.',
 'Comportamento exemplar. Feedback positivo imediato aplicado.',
 'ativo', '2026-04-30 08:15:00-03', '2026-04-30 08:15:00-03'),

('e0000000-0000-0000-0000-000000000002',
 '2026-04-30', '09:30', 'd1000000-0000-0000-0000-000000000009',
 'Ana Costa', 'ana.costa@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-18-0002', 'Trabalhador Beta',
 'Montagem de andaime — Setor B', 'Setor B — Linha 3',
 'a1000000-0000-0000-0000-000000000001', 'Security Dynamics',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Trabalhador realizando montagem de andaime sem cinto de segurança em altura superior a 2 metros.',
 'Intervenção imediata realizada. Trabalhador orientado e equipado corretamente.',
 'ativo', '2026-04-30 09:30:00-03', '2026-04-30 09:30:00-03'),

('e0000000-0000-0000-0000-000000000003',
 '2026-04-30', '10:00', 'd1000000-0000-0000-0000-000000000008',
 'Pedro Santos', 'pedro.santos@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-18-0003', 'Trabalhador Gamma',
 'Carregamento de caminhão — doca 2', 'Doca 2 — Expedição',
 'a1000000-0000-0000-0000-000000000002', 'Polo Norte',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Equipe organizada, utilizando check-list de carregamento e conferindo documentação antes da liberação.',
 NULL,
 'ativo', '2026-04-30 10:00:00-03', '2026-04-30 10:00:00-03'),

('e0000000-0000-0000-0000-000000000004',
 '2026-04-30', '13:45', 'd1000000-0000-0000-0000-000000000006',
 'João Silva', 'joao.silva@securitydynamics.com.br', 'supervisor', 'Security Dynamics',
 'OFS-2026-18-0004', 'Trabalhador Delta',
 'Limpeza de área — Setor C', 'Setor C — Área externa',
 'a1000000-0000-0000-0000-000000000003', 'G4S',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '2', 'OFS',
 'Trabalhador organizando materiais recicláveis com separação correta e uso de luvas adequadas.',
 NULL,
 'ativo', '2026-04-30 13:45:00-03', '2026-04-30 13:45:00-03'),

('e0000000-0000-0000-0000-000000000005',
 '2026-04-30', '15:20', 'd1000000-0000-0000-0000-000000000009',
 'Ana Costa', 'ana.costa@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-18-0005', 'Trabalhador Epsilon',
 'Manutenção de correia transportadora', 'Setor A — Transportador 5',
 'a1000000-0000-0000-0000-000000000001', 'Security Dynamics',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '2', 'OFS',
 'Trabalhador realizando manutenção com máquina ligada e sem bloqueio de energia (LOTO).',
 'Parada imediata solicitada. Aplicado procedimento de bloqueio antes da continuação.',
 'ativo', '2026-04-30 15:20:00-03', '2026-04-30 15:20:00-03'),

('e0000000-0000-0000-0000-000000000006',
 '2026-05-01', '07:40', 'd1000000-0000-0000-0000-000000000008',
 'Pedro Santos', 'pedro.santos@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-18-0006', 'Trabalhadora Zeta',
 'Inspeção de qualidade — linha 1', 'Linha 1 — Controle de Qualidade',
 'a1000000-0000-0000-0000-000000000004', 'ERA',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Inspeção minuciosa seguindo plano de amostragem, com registro correto em sistema.',
 NULL,
 'ativo', '2026-05-01 07:40:00-03', '2026-05-01 07:40:00-03'),

('e0000000-0000-0000-0000-000000000007',
 '2026-05-01', '10:30', 'd1000000-0000-0000-0000-000000000009',
 'Ana Costa', 'ana.costa@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-18-0007', 'Trabalhador Eta',
 'Soldagem de estruturas metálicas', 'Setor D — Soldagem',
 'a1000000-0000-0000-0000-000000000005', 'Innovatec',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Uso correto de máscara de solda, avental e luvas. Área isolada conforme norma.',
 NULL,
 'ativo', '2026-05-01 10:30:00-03', '2026-05-01 10:30:00-03'),

('e0000000-0000-0000-0000-000000000008',
 '2026-05-01', '14:00', 'd1000000-0000-0000-0000-000000000008',
 'Pedro Santos', 'pedro.santos@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-18-0008', 'Trabalhador Theta',
 'Movimentação de carga com ponte rolante', 'Galpão B — Ponte rolante 2',
 'a1000000-0000-0000-0000-000000000001', 'Security Dynamics',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '2', 'OFS',
 'Operador não conferiu capacidade máxima da ponte rolante antes da movimentação. Carga próxima do limite.',
 'Orientação sobre procedimento de verificação de capacidade antes de cada içamento.',
 'ativo', '2026-05-01 14:00:00-03', '2026-05-01 14:00:00-03'),

('e0000000-0000-0000-0000-000000000009',
 '2026-05-02', '08:00', 'd1000000-0000-0000-0000-000000000007',
 'Maria Oliveira', 'maria.oliveira@securitydynamics.com.br', 'supervisor', 'Security Dynamics',
 'OFS-2026-18-0009', 'Trabalhador Iota',
 'Reabastecimento de linha de produção', 'Linha 3 — Abastecimento',
 'a1000000-0000-0000-0000-000000000006', 'Conin',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Organização exemplar do posto de trabalho, materiais identificados e área limpa.',
 NULL,
 'ativo', '2026-05-02 08:00:00-03', '2026-05-02 08:00:00-03'),

('e0000000-0000-0000-0000-000000000010',
 '2026-05-02', '11:15', 'd1000000-0000-0000-0000-000000000009',
 'Ana Costa', 'ana.costa@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-18-0010', 'Trabalhador Kappa',
 'Operação de prensa hidráulica', 'Setor E — Prensas',
 'a1000000-0000-0000-0000-000000000007', 'FM',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Dispositivo de segurança da prensa (cortina de luz) estava desativado. Risco grave de acidente.',
 'Máquina parada imediatamente. Manutenção acionada para restabelecer dispositivo de segurança.',
 'ativo', '2026-05-02 11:15:00-03', '2026-05-02 11:15:00-03'),

('e0000000-0000-0000-0000-000000000011',
 '2026-05-02', '16:30', 'd1000000-0000-0000-0000-000000000008',
 'Pedro Santos', 'pedro.santos@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-18-0011', 'Trabalhadora Lambda',
 'Separação de pedidos — armazém', 'Armazém — Rua 7',
 'a1000000-0000-0000-0000-000000000001', 'Security Dynamics',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '2', 'OFS',
 'Trabalhadora utilizando scanner e conferindo produtos com atenção, zero erros de separação no dia.',
 NULL,
 'ativo', '2026-05-02 16:30:00-03', '2026-05-02 16:30:00-03'),

('e0000000-0000-0000-0000-000000000012',
 '2026-05-03', '07:00', 'd1000000-0000-0000-0000-000000000006',
 'João Silva', 'joao.silva@securitydynamics.com.br', 'supervisor', 'Security Dynamics',
 'OFS-2026-18-0012', 'Trabalhador Mu',
 'Limpeza industrial — Setor F', 'Setor F — Área química',
 'a1000000-0000-0000-0000-000000000008', 'Sodexo',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Uso completo de EPIs para área química (respirador, luvas nitrílicas, óculos). Seguiu POP de limpeza.',
 NULL,
 'ativo', '2026-05-03 07:00:00-03', '2026-05-03 07:00:00-03'),

-- ====== Semana 2: 05/05 a 11/05 (semana 19) ======
('e0000000-0000-0000-0000-000000000013',
 '2026-05-05', '08:30', 'd1000000-0000-0000-0000-000000000008',
 'Pedro Santos', 'pedro.santos@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-19-0001', 'Trabalhador Nu',
 'Carregamento de granel — silo 3', 'Silo 3 — Carregamento',
 'a1000000-0000-0000-0000-000000000009', 'Engecom',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Operador conferindo lacres, balança e documentação fiscal antes da liberação do veículo.',
 NULL,
 'ativo', '2026-05-05 08:30:00-03', '2026-05-05 08:30:00-03'),

('e0000000-0000-0000-0000-000000000014',
 '2026-05-05', '09:45', 'd1000000-0000-0000-0000-000000000009',
 'Ana Costa', 'ana.costa@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-19-0002', 'Trabalhadora Xi',
 'Embalagem de produtos — linha 5', 'Linha 5 — Embalagem',
 'a1000000-0000-0000-0000-000000000002', 'Polo Norte',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Ritmo consistente, verificando selagem e data de validade em cada embalagem.',
 NULL,
 'ativo', '2026-05-05 09:45:00-03', '2026-05-05 09:45:00-03'),

('e0000000-0000-0000-0000-000000000015',
 '2026-05-05', '14:20', 'd1000000-0000-0000-0000-000000000007',
 'Maria Oliveira', 'maria.oliveira@securitydynamics.com.br', 'supervisor', 'Security Dynamics',
 'OFS-2026-19-0003', 'Trabalhador Omicron',
 'Manutenção preventiva — compressor', 'Sala de compressores',
 'a1000000-0000-0000-0000-000000000001', 'Security Dynamics',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '2', 'OFS',
 'Manutenção realizada sem permissão de trabalho (PT) preenchida. Procedimento crítico.',
 'PT emitida após intervenção. Reforço sobre obrigatoriedade da PT para qualquer manutenção.',
 'ativo', '2026-05-05 14:20:00-03', '2026-05-05 14:20:00-03'),

('e0000000-0000-0000-0000-000000000016',
 '2026-05-06', '08:00', 'd1000000-0000-0000-0000-000000000008',
 'Pedro Santos', 'pedro.santos@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-19-0004', 'Trabalhador Pi',
 'Operação de caldeira', 'Caldeiraria',
 'a1000000-0000-0000-0000-000000000010', 'P&G',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Operador monitorando pressão e temperatura rigorosamente, registrando leituras a cada 30 minutos.',
 NULL,
 'ativo', '2026-05-06 08:00:00-03', '2026-05-06 08:00:00-03'),

('e0000000-0000-0000-0000-000000000017',
 '2026-05-06', '10:15', 'd1000000-0000-0000-0000-000000000009',
 'Ana Costa', 'ana.costa@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-19-0005', 'Trabalhador Rho',
 'Descarga de matéria-prima', 'Pátio de descarga',
 'a1000000-0000-0000-0000-000000000011', 'Yusen',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Motorista sem colete refletivo na área de circulação de veículos.',
 'Abordagem imediata. Colete fornecido e motorista orientado sobre obrigatoriedade.',
 'ativo', '2026-05-06 10:15:00-03', '2026-05-06 10:15:00-03'),

('e0000000-0000-0000-0000-000000000018',
 '2026-05-06', '13:00', 'd1000000-0000-0000-0000-000000000006',
 'João Silva', 'joao.silva@securitydynamics.com.br', 'supervisor', 'Security Dynamics',
 'OFS-2026-19-0006', 'Trabalhadora Sigma',
 'Controle de acesso — portaria 2', 'Portaria 2',
 'a1000000-0000-0000-0000-000000000001', 'Security Dynamics',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '2', 'OFS',
 'Atendente conferindo documentos, registrando entrada/saída e orientando visitantes com cordialidade.',
 NULL,
 'ativo', '2026-05-06 13:00:00-03', '2026-05-06 13:00:00-03'),

('e0000000-0000-0000-0000-000000000019',
 '2026-05-07', '07:30', 'd1000000-0000-0000-0000-000000000008',
 'Pedro Santos', 'pedro.santos@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-19-0007', 'Trabalhador Tau',
 'Pintura industrial — cabine 1', 'Cabine de pintura 1',
 'a1000000-0000-0000-0000-000000000012', 'Mainpower',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Pintor utilizando traje Tyvek completo e máscara com filtro adequado. Cabine com exaustor funcionando.',
 NULL,
 'ativo', '2026-05-07 07:30:00-03', '2026-05-07 07:30:00-03'),

('e0000000-0000-0000-0000-000000000020',
 '2026-05-07', '11:00', 'd1000000-0000-0000-0000-000000000009',
 'Ana Costa', 'ana.costa@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-19-0008', 'Trabalhador Upsilon',
 'Movimentação de tambores químicos', 'Armazém químico',
 'a1000000-0000-0000-0000-000000000001', 'Security Dynamics',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Tambores armazenados sem bacia de contenção. Risco de vazamento para o solo.',
 'Bacia de contenção instalada no mesmo dia. Não conformidade registrada.',
 'ativo', '2026-05-07 11:00:00-03', '2026-05-07 11:00:00-03'),

('e0000000-0000-0000-0000-000000000021',
 '2026-05-07', '15:45', 'd1000000-0000-0000-0000-000000000007',
 'Maria Oliveira', 'maria.oliveira@securitydynamics.com.br', 'supervisor', 'Security Dynamics',
 'OFS-2026-19-0009', 'Trabalhador Phi',
 'Inspeção de extintores', 'Área externa — pontos de incêndio',
 'a1000000-0000-0000-0000-000000000003', 'G4S',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '2', 'OFS',
 'Brigadista revisando todos os extintores conforme check-list mensal, com registro fotográfico.',
 NULL,
 'ativo', '2026-05-07 15:45:00-03', '2026-05-07 15:45:00-03'),

('e0000000-0000-0000-0000-000000000022',
 '2026-05-08', '08:10', 'd1000000-0000-0000-0000-000000000008',
 'Pedro Santos', 'pedro.santos@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-19-0010', 'Trabalhador Chi',
 'Recebimento de mercadoria', 'Doca 4 — Recebimento',
 'a1000000-0000-0000-0000-000000000013', 'Aduana',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Conferente atento a avarias, registrando divergências e comunicando supervisor imediatamente.',
 NULL,
 'ativo', '2026-05-08 08:10:00-03', '2026-05-08 08:10:00-03'),

('e0000000-0000-0000-0000-000000000023',
 '2026-05-08', '10:30', 'd1000000-0000-0000-0000-000000000005',
 'Carlos Gestor', 'gestor@securitydynamics.com.br', 'gestor', 'Security Dynamics',
 'OFS-2026-19-0011', 'Trabalhador Psi',
 'Teste hidrostático — mangueiras', 'Laboratório de testes',
 'a1000000-0000-0000-0000-000000000004', 'ERA',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Operador não calibrou manômetro antes do teste. Resultados podem ser imprecisos.',
 'Ensaio interrompido. Manômetro calibrado e teste reiniciado corretamente.',
 'ativo', '2026-05-08 10:30:00-03', '2026-05-08 10:30:00-03'),

('e0000000-0000-0000-0000-000000000024',
 '2026-05-08', '14:00', 'd1000000-0000-0000-0000-000000000009',
 'Ana Costa', 'ana.costa@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-19-0012', 'Trabalhador Omega',
 'Fracionamento de produtos', 'Setor G — Fracionamento',
 'a1000000-0000-0000-0000-000000000001', 'Security Dynamics',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '2', 'OFS',
 'Uso correto de balança de precisão, registrando lote e validade de cada fração no sistema.',
 NULL,
 'ativo', '2026-05-08 14:00:00-03', '2026-05-08 14:00:00-03'),

('e0000000-0000-0000-0000-000000000025',
 '2026-05-09', '07:00', 'd1000000-0000-0000-0000-000000000006',
 'João Silva', 'joao.silva@securitydynamics.com.br', 'supervisor', 'Security Dynamics',
 'OFS-2026-19-0013', 'Trabalhador Alpha2',
 'Abertura de turno — DDS', 'Sala de reunião — Galpão A',
 'a1000000-0000-0000-0000-000000000001', 'Security Dynamics',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Líder conduziu DDS (Diálogo Diário de Segurança) com tema relevante e participação ativa da equipe.',
 NULL,
 'ativo', '2026-05-09 07:00:00-03', '2026-05-09 07:00:00-03'),

-- ====== Semana 3: 12/05 a 18/05 (semana 20) ======
('e0000000-0000-0000-0000-000000000026',
 '2026-05-12', '08:00', 'd1000000-0000-0000-0000-000000000008',
 'Pedro Santos', 'pedro.santos@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-20-0001', 'Trabalhadora Beta2',
 'Corte a laser — CNC 3', 'Setor H — CNC',
 'a1000000-0000-0000-0000-000000000014', 'Prosegur',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Operadora com proteção ocular adequada, seguindo programação e mantendo área isolada.',
 NULL,
 'ativo', '2026-05-12 08:00:00-03', '2026-05-12 08:00:00-03'),

('e0000000-0000-0000-0000-000000000027',
 '2026-05-12', '09:30', 'd1000000-0000-0000-0000-000000000009',
 'Ana Costa', 'ana.costa@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-20-0002', 'Trabalhador Gamma2',
 'Expedição de produto acabado', 'Expedição — Doca 5',
 'a1000000-0000-0000-0000-000000000005', 'Innovatec',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Palete com altura excessiva dificultando visão do operador de empilhadeira.',
 'Palete reorganizado. Limite de altura reforçado com a equipe de expedição.',
 'ativo', '2026-05-12 09:30:00-03', '2026-05-12 09:30:00-03'),

('e0000000-0000-0000-0000-000000000028',
 '2026-05-12', '11:00', 'd1000000-0000-0000-0000-000000000007',
 'Maria Oliveira', 'maria.oliveira@securitydynamics.com.br', 'supervisor', 'Security Dynamics',
 'OFS-2026-20-0003', 'Trabalhador Delta2',
 'Carga de baterias — empilhadeiras', 'Sala de baterias',
 'a1000000-0000-0000-0000-000000000001', 'Security Dynamics',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Operador seguindo procedimento de troca de baterias com uso de EPIs e verificação de nível de eletrólito.',
 NULL,
 'ativo', '2026-05-12 11:00:00-03', '2026-05-12 11:00:00-03'),

('e0000000-0000-0000-0000-000000000029',
 '2026-05-12', '14:30', 'd1000000-0000-0000-0000-000000000008',
 'Pedro Santos', 'pedro.santos@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-20-0004', 'Equipe Epsilon2',
 'Simulado de emergência', 'Ponto de encontro — Estacionamento',
 'a1000000-0000-0000-0000-000000000001', 'Security Dynamics',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '2', 'OFS',
 'Equipe respondeu ao alarme em 2min30s, todos no ponto de encontro com contagem realizada.',
 'Tempo dentro da meta de 3 minutos. Parabéns à equipe.',
 'ativo', '2026-05-12 14:30:00-03', '2026-05-12 14:30:00-03'),

('e0000000-0000-0000-0000-000000000030',
 '2026-05-13', '08:15', 'd1000000-0000-0000-0000-000000000005',
 'Carlos Gestor', 'gestor@securitydynamics.com.br', 'gestor', 'Security Dynamics',
 'OFS-2026-20-0005', 'Trabalhador Zeta2',
 'Operação de misturador industrial', 'Setor I — Mistura',
 'a1000000-0000-0000-0000-000000000006', 'Conin',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Operador abriu tampa do misturador antes da parada total do equipamento.',
 'Intervenção imediata. Reciclagem sobre procedimento de segurança agendada para o operador.',
 'ativo', '2026-05-13 08:15:00-03', '2026-05-13 08:15:00-03'),

('e0000000-0000-0000-0000-000000000031',
 '2026-05-13', '10:45', 'd1000000-0000-0000-0000-000000000009',
 'Ana Costa', 'ana.costa@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-20-0006', 'Trabalhadora Eta2',
 'Análise laboratorial — amostras', 'Laboratório central',
 'a1000000-0000-0000-0000-000000000007', 'FM',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Analista seguindo POP de análise, com calibração prévia dos equipamentos e registro em sistema LIMS.',
 NULL,
 'ativo', '2026-05-13 10:45:00-03', '2026-05-13 10:45:00-03'),

('e0000000-0000-0000-0000-000000000032',
 '2026-05-13', '13:00', 'd1000000-0000-0000-0000-000000000006',
 'João Silva', 'joao.silva@securitydynamics.com.br', 'supervisor', 'Security Dynamics',
 'OFS-2026-20-0007', 'Trabalhadora Theta2',
 'Higienização de equipamentos', 'Setor J — CIP',
 'a1000000-0000-0000-0000-000000000008', 'Sodexo',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '2', 'OFS',
 'Procedimento CIP executado com parâmetros corretos (temperatura, concentração, tempo).',
 NULL,
 'ativo', '2026-05-13 13:00:00-03', '2026-05-13 13:00:00-03'),

('e0000000-0000-0000-0000-000000000033',
 '2026-05-14', '07:45', 'd1000000-0000-0000-0000-000000000008',
 'Pedro Santos', 'pedro.santos@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-20-0008', 'Trabalhador Iota2',
 'Amarração de carga — veículo', 'Pátio de carregamento',
 'a1000000-0000-0000-0000-000000000009', 'Engecom',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Carga mal amarrada com cintas frouxas. Risco de queda durante transporte.',
 'Recarga corrigida. Motorista orientado sobre verificação de tensionamento das cintas.',
 'ativo', '2026-05-14 07:45:00-03', '2026-05-14 07:45:00-03'),

('e0000000-0000-0000-0000-000000000034',
 '2026-05-14', '10:00', 'd1000000-0000-0000-0000-000000000009',
 'Ana Costa', 'ana.costa@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-20-0009', 'Trabalhadora Kappa2',
 'Montagem de kits', 'Setor K — Montagem',
 'a1000000-0000-0000-0000-000000000002', 'Polo Norte',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Organização exemplar da bancada, componentes separados por lote e verificação dupla antes da montagem.',
 NULL,
 'ativo', '2026-05-14 10:00:00-03', '2026-05-14 10:00:00-03'),

('e0000000-0000-0000-0000-000000000035',
 '2026-05-14', '15:00', 'd1000000-0000-0000-0000-000000000007',
 'Maria Oliveira', 'maria.oliveira@securitydynamics.com.br', 'supervisor', 'Security Dynamics',
 'OFS-2026-20-0010', 'Trabalhador Lambda2',
 'Esgotamento de tanque — ETE', 'Estação de tratamento',
 'a1000000-0000-0000-0000-000000000010', 'P&G',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '2', 'OFS',
 'Operador sem luva adequada para manuseio de produtos químicos na ETE.',
 'Luva fornecida. Registro de desvio para controle de EPIs.',
 'ativo', '2026-05-14 15:00:00-03', '2026-05-14 15:00:00-03'),

('e0000000-0000-0000-0000-000000000036',
 '2026-05-15', '08:30', 'd1000000-0000-0000-0000-000000000008',
 'Pedro Santos', 'pedro.santos@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-20-0011', 'Trabalhador Mu2',
 'Triagem de resíduos', 'Central de resíduos',
 'a1000000-0000-0000-0000-000000000001', 'Security Dynamics',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Triagem correta de resíduos por classe, com uso de todos os EPIs e registros em planilha.',
 NULL,
 'ativo', '2026-05-15 08:30:00-03', '2026-05-15 08:30:00-03'),

('e0000000-0000-0000-0000-000000000037',
 '2026-05-15', '14:15', 'd1000000-0000-0000-0000-000000000009',
 'Ana Costa', 'ana.costa@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-20-0012', 'Trabalhador Nu2',
 'Inventário rotativo — almoxarifado', 'Almoxarifado central',
 'a1000000-0000-0000-0000-000000000011', 'Yusen',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '2', 'OFS',
 'Contagem precisa, divergências reportadas e itens vencidos segregados corretamente.',
 NULL,
 'ativo', '2026-05-15 14:15:00-03', '2026-05-15 14:15:00-03'),

-- ====== Semana 4: 19/05 a 25/05 (semana 21) ======
('e0000000-0000-0000-0000-000000000038',
 '2026-05-19', '08:00', 'd1000000-0000-0000-0000-000000000008',
 'Pedro Santos', 'pedro.santos@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-21-0001', 'Trabalhador Xi2',
 'Envasamento de produto', 'Linha 2 — Envase',
 'a1000000-0000-0000-0000-000000000012', 'Mainpower',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Operador conferindo nível de envase, bico dosador e integridade do lacre em cada unidade.',
 NULL,
 'ativo', '2026-05-19 08:00:00-03', '2026-05-19 08:00:00-03'),

('e0000000-0000-0000-0000-000000000039',
 '2026-05-19', '10:30', 'd1000000-0000-0000-0000-000000000005',
 'Carlos Gestor', 'gestor@securitydynamics.com.br', 'gestor', 'Security Dynamics',
 'OFS-2026-21-0002', 'Trabalhador Omicron2',
 'Manobra de veículos — pátio', 'Pátio de manobras',
 'a1000000-0000-0000-0000-000000000013', 'Aduana',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Motorista realizando manobra sem sinaleiro (ajudante de pátio).',
 'Procedimento interrompido. Sinaleiro acionado para auxiliar na manobra.',
 'ativo', '2026-05-19 10:30:00-03', '2026-05-19 10:30:00-03'),

('e0000000-0000-0000-0000-000000000040',
 '2026-05-19', '14:00', 'd1000000-0000-0000-0000-000000000006',
 'João Silva', 'joao.silva@securitydynamics.com.br', 'supervisor', 'Security Dynamics',
 'OFS-2026-21-0003', 'Trabalhador Pi2',
 'Teste de estanqueidade — tubulação', 'Setor L — Tubulação',
 'a1000000-0000-0000-0000-000000000001', 'Security Dynamics',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '2', 'OFS',
 'Técnico utilizando equipamento calibrado, seguindo norma de teste hidrostático e registrando resultados.',
 NULL,
 'ativo', '2026-05-19 14:00:00-03', '2026-05-19 14:00:00-03'),

('e0000000-0000-0000-0000-000000000041',
 '2026-05-20', '07:20', 'd1000000-0000-0000-0000-000000000009',
 'Ana Costa', 'ana.costa@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-21-0004', 'Trabalhadora Rho2',
 'Preparação de soluções — laboratório', 'Laboratório de química',
 'a1000000-0000-0000-0000-000000000014', 'Prosegur',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Trabalhadora utilizando capela de exaustão, pipetador automático e identificando todas as soluções.',
 NULL,
 'ativo', '2026-05-20 07:20:00-03', '2026-05-20 07:20:00-03'),

('e0000000-0000-0000-0000-000000000042',
 '2026-05-20', '11:15', 'd1000000-0000-0000-0000-000000000008',
 'Pedro Santos', 'pedro.santos@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-21-0005', 'Trabalhador Sigma2',
 'Abertura de valeta — obra civil', 'Canteiro de obras — Setor M',
 'a1000000-0000-0000-0000-000000000001', 'Security Dynamics',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Valeta com mais de 1,5m sem escoramento adequado. Risco de desmoronamento.',
 'Atividade suspensa até instalação de escoramento conforme NR-18.',
 'ativo', '2026-05-20 11:15:00-03', '2026-05-20 11:15:00-03'),

('e0000000-0000-0000-0000-000000000043',
 '2026-05-20', '13:45', 'd1000000-0000-0000-0000-000000000007',
 'Maria Oliveira', 'maria.oliveira@securitydynamics.com.br', 'supervisor', 'Security Dynamics',
 'OFS-2026-21-0006', 'Trabalhadora Tau2',
 'Costura industrial — linha 8', 'Linha 8 — Confecção',
 'a1000000-0000-0000-0000-000000000003', 'G4S',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '2', 'OFS',
 'Operadora com postura ergonômica correta, iluminação adequada e pausas programadas respeitadas.',
 NULL,
 'ativo', '2026-05-20 13:45:00-03', '2026-05-20 13:45:00-03'),

('e0000000-0000-0000-0000-000000000044',
 '2026-05-21', '08:00', 'd1000000-0000-0000-0000-000000000009',
 'Ana Costa', 'ana.costa@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-21-0007', 'Trabalhadora Upsilon2',
 'Reunião de segurança semanal', 'Sala de treinamento',
 'a1000000-0000-0000-0000-000000000001', 'Security Dynamics',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Equipe participativa, com relatos de quase-acidentes e sugestões de melhoria registradas em ata.',
 NULL,
 'ativo', '2026-05-21 08:00:00-03', '2026-05-21 08:00:00-03'),

('e0000000-0000-0000-0000-000000000045',
 '2026-05-21', '10:30', 'd1000000-0000-0000-0000-000000000008',
 'Pedro Santos', 'pedro.santos@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-21-0008', 'Trabalhador Phi2',
 'Carga de big bags — armazém', 'Armazém — Big bags',
 'a1000000-0000-0000-0000-000000000004', 'ERA',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Operação segura com empilhadeira, área isolada e sinalização adequada para circulação.',
 NULL,
 'ativo', '2026-05-21 10:30:00-03', '2026-05-21 10:30:00-03'),

('e0000000-0000-0000-0000-000000000046',
 '2026-05-21', '15:30', 'd1000000-0000-0000-0000-000000000006',
 'João Silva', 'joao.silva@securitydynamics.com.br', 'supervisor', 'Security Dynamics',
 'OFS-2026-21-0009', 'Trabalhador Chi2',
 'Manutenção corretiva — bomba', 'Casa de bombas',
 'a1000000-0000-0000-0000-000000000005', 'Innovatec',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '2', 'OFS',
 'Bomba desligada mas disjuntor não bloqueado. Risco de reenergização acidental.',
 'Bloqueio e etiquetagem (LOTO) aplicados antes da continuação do serviço.',
 'ativo', '2026-05-21 15:30:00-03', '2026-05-21 15:30:00-03'),

('e0000000-0000-0000-0000-000000000047',
 '2026-05-22', '07:30', 'd1000000-0000-0000-0000-000000000009',
 'Ana Costa', 'ana.costa@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-21-0010', 'Trabalhadora Psi2',
 'Arrumação de prateleiras — loja', 'Loja — Corredor 3',
 'a1000000-0000-0000-0000-000000000006', 'Conin',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Repositora organizando produtos por validade (PEPS), com etiquetas de preço visíveis e corretas.',
 NULL,
 'ativo', '2026-05-22 07:30:00-03', '2026-05-22 07:30:00-03'),

('e0000000-0000-0000-0000-000000000048',
 '2026-05-22', '11:00', 'd1000000-0000-0000-0000-000000000007',
 'Maria Oliveira', 'maria.oliveira@securitydynamics.com.br', 'supervisor', 'Security Dynamics',
 'OFS-2026-21-0011', 'Trabalhador Omega2',
 'Solda em tubulação de vapor', 'Setor N — Utilidades',
 'a1000000-0000-0000-0000-000000000001', 'Security Dynamics',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Soldador com todos os EPIs, biombo de proteção instalado e permissão de trabalho a quente válida.',
 NULL,
 'ativo', '2026-05-22 11:00:00-03', '2026-05-22 11:00:00-03'),

('e0000000-0000-0000-0000-000000000049',
 '2026-05-22', '14:00', 'd1000000-0000-0000-0000-000000000005',
 'Carlos Gestor', 'gestor@securitydynamics.com.br', 'gestor', 'Security Dynamics',
 'OFS-2026-21-0012', 'Trabalhador Alpha3',
 'Encerramento de turno — inspeção', 'Galpão A',
 'a1000000-0000-0000-0000-000000000001', 'Security Dynamics',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '2', 'OFS',
 'Supervisor conduziu inspeção de encerramento verificando máquinas desligadas, EPIs guardados e área limpa.',
 NULL,
 'ativo', '2026-05-22 14:00:00-03', '2026-05-22 14:00:00-03'),

('e0000000-0000-0000-0000-000000000050',
 '2026-05-23', '08:00', 'd1000000-0000-0000-0000-000000000008',
 'Pedro Santos', 'pedro.santos@securitydynamics.com.br', 'observador', 'Security Dynamics',
 'OFS-2026-21-0013', 'Trabalhadora Beta3',
 'Atendimento ao cliente — balcão', 'Balcão de atendimento',
 'a1000000-0000-0000-0000-000000000001', 'Security Dynamics',
 'f1000000-0000-0000-0000-000000000001', 'Operação Security Dynamics',
 '1', 'OFS',
 'Atendente cordial, resolvendo dúvidas com clareza e registrando protocolo de atendimento no sistema.',
 NULL,
 'ativo', '2026-05-23 08:00:00-03', '2026-05-23 08:00:00-03')
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- SEÇÃO H: VERIFICAÇÃO FINAL
-- ============================================================================
DO $$
DECLARE
    v_empresas  INT;
    v_usuarios  INT;
    v_OFSS      INT;
    v_metas     INT;
BEGIN
    SELECT COUNT(*) INTO v_empresas FROM empresas;
    SELECT COUNT(*) INTO v_usuarios FROM usuarios;
    SELECT COUNT(*) INTO v_OFSS FROM OFSS;
    SELECT COUNT(*) INTO v_metas FROM metas;

    RAISE NOTICE '========== VERIFICAÇÃO DE SEED ==========';
    RAISE NOTICE 'Empresas cadastradas : %', v_empresas;
    RAISE NOTICE 'Usuários cadastrados : %', v_usuarios;
    RAISE NOTICE 'OFSS de exemplo      : %', v_OFSS;
    RAISE NOTICE 'Metas cadastradas    : %', v_metas;
    RAISE NOTICE '==========================================';
END;
$$;

-- ============================================================================
-- FIM DA MIGRATION 002
-- ============================================================================
