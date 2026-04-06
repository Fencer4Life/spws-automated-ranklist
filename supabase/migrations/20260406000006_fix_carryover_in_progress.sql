-- =============================================================================
-- Fix: carry-over should be dropped when event is IN_PROGRESS (not just COMPLETED)
-- =============================================================================
-- Patches fn_ranking_ppw and fn_ranking_kadra by reading their current source,
-- replacing the COMPLETED-only filter with COMPLETED + IN_PROGRESS, and
-- recreating the functions.
-- =============================================================================

-- Patch fn_ranking_ppw
DO $patch$
DECLARE
  v_src TEXT;
  v_full TEXT;
BEGIN
  SELECT pg_get_functiondef(oid) INTO v_full
  FROM pg_proc
  WHERE proname = 'fn_ranking_ppw'
    AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

  IF v_full IS NULL THEN
    RAISE NOTICE 'fn_ranking_ppw not found, skipping';
    RETURN;
  END IF;

  -- Replace the COMPLETED-only filter
  v_full := replace(v_full,
    $$ev.enum_status = 'COMPLETED'$$,
    $$ev.enum_status IN ('COMPLETED', 'IN_PROGRESS')$$
  );

  -- Replace CREATE FUNCTION with CREATE OR REPLACE FUNCTION
  v_full := replace(v_full,
    'CREATE FUNCTION',
    'CREATE OR REPLACE FUNCTION'
  );

  EXECUTE v_full;
END;
$patch$;


-- Patch fn_ranking_kadra
DO $patch2$
DECLARE
  v_full TEXT;
BEGIN
  SELECT pg_get_functiondef(oid) INTO v_full
  FROM pg_proc
  WHERE proname = 'fn_ranking_kadra'
    AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

  IF v_full IS NULL THEN
    RAISE NOTICE 'fn_ranking_kadra not found, skipping';
    RETURN;
  END IF;

  v_full := replace(v_full,
    $$ev.enum_status = 'COMPLETED'$$,
    $$ev.enum_status IN ('COMPLETED', 'IN_PROGRESS')$$
  );

  v_full := replace(v_full,
    'CREATE FUNCTION',
    'CREATE OR REPLACE FUNCTION'
  );

  EXECUTE v_full;
END;
$patch2$;
