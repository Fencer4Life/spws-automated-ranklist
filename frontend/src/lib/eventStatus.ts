import type { EventStatus } from './types'

export interface DisplayStatus {
  cssClass: string
  labelKey: string
}

// All 8 lifecycle states (ADR-077 §1) must have a badge. CREATED + SCORED were
// missing, so they silently fell through to the `?? BASE.PLANNED` fallback and
// rendered as "Planned" — masking skeleton (CREATED) and scored-pre-signoff
// (SCORED) events. The map is exhaustive over EventStatus so a future enum
// addition fails the type check instead of falling back silently.
const BASE: Record<EventStatus, DisplayStatus> = {
  CREATED:     { cssClass: 'status-created',     labelKey: 'status_created' },
  PLANNED:     { cssClass: 'status-planned',    labelKey: 'status_planned' },
  SCHEDULED:   { cssClass: 'status-scheduled',  labelKey: 'status_scheduled' },
  CHANGED:     { cssClass: 'status-changed',    labelKey: 'status_changed' },
  IN_PROGRESS: { cssClass: 'status-inprogress', labelKey: 'status_in_progress' },
  SCORED:      { cssClass: 'status-scored',      labelKey: 'status_scored' },
  COMPLETED:   { cssClass: 'status-completed',  labelKey: 'status_completed' },
  CANCELLED:   { cssClass: 'status-cancelled',  labelKey: 'status_cancelled' },
}

// PLANNED events whose end date has already passed are "Awaiting results":
// the event happened but the results pipeline hasn't caught up yet. The
// underlying enum_status stays PLANNED so ADR-018 rolling carry-over keeps
// working; only the UI label + badge colour differ.
export function getEventDisplayStatus(
  status: EventStatus,
  dt_end: string | null | undefined,
  dt_start?: string | null,
  today: string = new Date().toISOString().slice(0, 10),
): DisplayStatus {
  if (status === 'PLANNED') {
    const endDate = dt_end ?? dt_start ?? null
    if (endDate && endDate < today) {
      return { cssClass: 'status-awaiting', labelKey: 'status_awaiting_results' }
    }
  }
  return BASE[status] ?? BASE.PLANNED
}
