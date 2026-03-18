-- PDF Q&A Function: Uses AI_COMPLETE with TO_FILE to read PDFs on-demand
-- This enables "ask any question about a regulation" without pre-parsing

CREATE OR REPLACE FUNCTION REG_INTEL.ANALYTICS.ASK_REGULATION_PDF(
    doc_number STRING,
    question STRING
)
RETURNS STRING
LANGUAGE SQL
AS
$$
    SELECT AI_COMPLETE(
        MODEL => 'claude-4-sonnet',
        PROMPT => PROMPT(
            'You are a regulatory compliance analyst. Answer this question about the Federal Register regulation: ' || question || '

Be specific and cite relevant sections when possible. If deadlines or dates are mentioned, highlight them clearly.

Document: {0}',
            TO_FILE('@REG_INTEL.RAW.REGULATION_PDFS', doc_number || '.pdf')
        )
    )::STRING
$$;

-- Example usage:
-- SELECT REG_INTEL.ANALYTICS.ASK_REGULATION_PDF(
--     '2026-05312',
--     'What are the compliance deadlines and who must comply?'
-- );
