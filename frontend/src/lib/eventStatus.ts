import type { EventStatus } from './types'

export interface DisplayStatus {
  cssClass: string
  labelKey: string
}

const BASE: Record<EventStatus, DisplayStatus> = {
  PLANNED:     { cssClass: 'status-planned',    labelKey: 'status_planned' },
  SCHEDULED:   { cssClass: 'status-scheduled',  labelKey: 'status_scheduled' },
  CHANGED:     { cssClass: 'status-changed',    labelKey: 'status_changed' },
  IN_PROGRESS: { cssClass: 'status-inprogress', labelKey: 'status_in_progress' },
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
