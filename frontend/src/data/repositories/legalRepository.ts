import { getSupabaseClient, isSupabaseConfigured } from '../supabaseClient';
import { logger } from '../../utils/logger';

export type LegalDocumentType = 'terms_of_service' | 'privacy_policy';
export type LegalChangeLevel = 'major' | 'minor';
export type LegalComplianceStatus =
    | 'up_to_date'
    | 'minor_notice_available'
    | 'requires_major_acceptance';

export interface ActiveLegalDocument {
    version_id: string;
    document_type: LegalDocumentType;
    version_code: string;
    change_level: LegalChangeLevel;
    content: string;
    change_summary: string;
    published_at: string;
}

export interface ActiveLegalCatalog {
    terms_of_service: ActiveLegalDocument;
    privacy_policy: ActiveLegalDocument;
}

export interface StoreLegalStatus {
    store_id: string;
    compliance_status: LegalComplianceStatus;
    has_open_cash_session: boolean;
    pending_major_documents: ActiveLegalDocument[];
    pending_minor_notices: ActiveLegalDocument[];
    support_channel: {
        contact: string;
        message: string;
    };
    checked_at: string;
}

export interface LegalAcceptanceResult {
    store_id: string;
    acceptance_ids: string[];
    accepted_at: string;
}

export interface LegalVersionRecord {
    id: string;
    document_type: LegalDocumentType;
    version_code: string;
    change_level: LegalChangeLevel;
    content: string;
    change_summary: string;
    is_active: boolean;
    published_at: string;
}

export class LegalRepositoryError extends Error {
    code: string;
    constructor(message: string, code: string = 'LEGAL_ERROR') {
        super(message);
        this.name = 'LegalRepositoryError';
        this.code = code;
    }
}

function extractLegalError(err: any, fallbackMessage: string): LegalRepositoryError {
    const rawMsg = String(err?.message || err || '');
    if (rawMsg.includes('MISSING_ACTIVE_LEGAL_DOCUMENTS')) {
        return new LegalRepositoryError(
            'Aún no hay documentos legales vigentes configurados en la plataforma. Intenta nuevamente más tarde.',
            'MISSING_ACTIVE_LEGAL_DOCUMENTS'
        );
    }
    if (rawMsg.includes('LEGAL_VERSION_SUPERSEDED')) {
        return new LegalRepositoryError(
            'Se publicó una versión legal más reciente mientras revisabas el documento. Hemos recargado la versión vigente para que puedas revisarla.',
            'LEGAL_VERSION_SUPERSEDED'
        );
    }
    if (rawMsg.includes('LEGAL_ACCEPTANCE_REQUIRED')) {
        return new LegalRepositoryError(
            'Debes aceptar las versiones vigentes de Términos y Política de Datos.',
            'LEGAL_ACCEPTANCE_REQUIRED'
        );
    }
    if (rawMsg.includes('PLATFORM_OWNER_REQUIRED')) {
        return new LegalRepositoryError(
            'Solo el dueño de la plataforma SaaS puede publicar nuevas versiones legales.',
            'PLATFORM_OWNER_REQUIRED'
        );
    }
    if (rawMsg.includes('DUPLICATE_VERSION_CODE')) {
        return new LegalRepositoryError(
            'Ya existe un documento con ese código de versión.',
            'DUPLICATE_VERSION_CODE'
        );
    }
    if (rawMsg.includes('EMPTY_LEGAL_CONTENT')) {
        return new LegalRepositoryError(
            'Código de versión, contenido y resumen de cambios son obligatorios.',
            'EMPTY_LEGAL_CONTENT'
        );
    }
    if (rawMsg.includes('UNAUTHORIZED') || err?.code === '42501') {
        return new LegalRepositoryError(
            'No tienes permisos administrativos autorizados para realizar esta acción.',
            'UNAUTHORIZED'
        );
    }
    return new LegalRepositoryError(rawMsg || fallbackMessage, err?.code || 'LEGAL_ERROR');
}

function ensureOnlineSupabase() {
    if (typeof navigator !== 'undefined' && !navigator.onLine) {
        throw new LegalRepositoryError(
            'Sin conexión a internet. Esta consulta legal requiere conexión en línea.',
            'OFFLINE'
        );
    }
    if (!isSupabaseConfigured()) {
        throw new LegalRepositoryError(
            'El servicio en línea no está configurado en este dispositivo.',
            'SUPABASE_UNAVAILABLE'
        );
    }
    const client = getSupabaseClient();
    if (!client) {
        throw new LegalRepositoryError(
            'No se pudo conectar con el servidor de documentos legales.',
            'SUPABASE_UNAVAILABLE'
        );
    }
    return client;
}

export const legalRepository = {
    async getActiveDocuments(): Promise<ActiveLegalCatalog> {
        const supabase = ensureOnlineSupabase();
        const { data, error } = await (supabase as any).rpc('rpc_obtener_documentos_legales_vigentes');

        if (error) {
            logger.error('[LegalRepository] getActiveDocuments error:', error);
            throw extractLegalError(error, 'No fue posible consultar los documentos legales vigentes.');
        }

        const payload = data as any;
        if (!payload?.success || !payload?.data?.terms_of_service || !payload?.data?.privacy_policy) {
            throw new LegalRepositoryError(
                'La respuesta de documentos legales está incompleta.',
                'INVALID_LEGAL_PAYLOAD'
            );
        }

        return payload.data as ActiveLegalCatalog;
    },

    async checkStoreLegalStatus(storeId: string): Promise<StoreLegalStatus> {
        const supabase = ensureOnlineSupabase();
        const { data, error } = await (supabase as any).rpc('rpc_verificar_estado_legal_tienda', {
            p_store_id: storeId,
        });

        if (error) {
            logger.error('[LegalRepository] checkStoreLegalStatus error:', error);
            throw extractLegalError(error, 'No se pudo verificar el estado de cumplimiento legal.');
        }

        const payload = data as any;
        if (!payload?.success || !payload?.data) {
            throw new LegalRepositoryError('Respuesta inválida al verificar estado legal.', 'INVALID_LEGAL_PAYLOAD');
        }

        return payload.data as StoreLegalStatus;
    },

    async acceptLegalVersions(
        storeId: string,
        versionIds: string[],
        originChannel: string = 'web_login_gate'
    ): Promise<LegalAcceptanceResult> {
        const supabase = ensureOnlineSupabase();
        const { data, error } = await (supabase as any).rpc('rpc_aceptar_version_legal_tienda', {
            p_store_id: storeId,
            p_version_ids: versionIds,
            p_origin_channel: originChannel,
        });

        if (error) {
            logger.error('[LegalRepository] acceptLegalVersions error:', error);
            throw extractLegalError(error, 'No se pudo registrar tu aceptación legal.');
        }

        const payload = data as any;
        if (!payload?.success || !payload?.data) {
            throw new LegalRepositoryError('No se recibió confirmación del servidor.', 'INVALID_LEGAL_PAYLOAD');
        }

        return payload.data as LegalAcceptanceResult;
    },

    async listAllVersions(): Promise<LegalVersionRecord[]> {
        const supabase = ensureOnlineSupabase();
        const { data, error } = await (supabase as any)
            .from('legal_document_versions')
            .select('id, document_type, version_code, change_level, content, change_summary, is_active, published_at')
            .order('published_at', { ascending: false });

        if (error) {
            logger.error('[LegalRepository] listAllVersions error:', error);
            throw extractLegalError(error, 'No se pudo consultar el historial de versiones legales.');
        }

        return (data || []) as LegalVersionRecord[];
    },

    async publishLegalVersion(input: {
        documentType: LegalDocumentType;
        versionCode: string;
        changeLevel: LegalChangeLevel;
        content: string;
        changeSummary: string;
    }) {
        const supabase = ensureOnlineSupabase();
        const { data, error } = await (supabase as any).rpc('rpc_publicar_version_legal', {
            p_document_type: input.documentType,
            p_version_code: input.versionCode,
            p_change_level: input.changeLevel,
            p_content: input.content,
            p_change_summary: input.changeSummary,
        });

        if (error) {
            logger.error('[LegalRepository] publishLegalVersion error:', error);
            throw extractLegalError(error, 'No se pudo publicar la versión legal.');
        }

        const payload = data as any;
        if (!payload?.success || !payload?.data) {
            throw new LegalRepositoryError('No se recibió confirmación de publicación.', 'INVALID_LEGAL_PAYLOAD');
        }

        return payload.data;
    },
};

export default legalRepository;
