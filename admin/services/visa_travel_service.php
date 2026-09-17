<?php

declare(strict_types=1);

require_once __DIR__ . '/../config/supabase.php';

class VisaTravelService
{
    private const EXPIRING_SOON_DAYS = 10;

    public function __construct(
        private SupabaseClient $supabase
    ) {
    }

    // Travel context
    public function getTravelContext(string $submissionId): ?array
    {
        $submission = $this->getSubmission($submissionId);

        if ($submission === null) {
            return null;
        }

        $records = $this->getTravelRecords($submissionId);
        $plannedTravel = $this->getPlannedTravelInformation(
            (string)($submission['application_id'] ?? '')
        );

        $state = $this->calculateTravelState(
            $submission,
            $records
        );

        return [
            'submission' => $submission,
            'planned_travel' => $plannedTravel,
            'records' => $records,
            'state' => $state,
            'remaining_days' => $this->calculateRemainingDays($records),
            'current_record' => $this->getCurrentOpenRecord($records),
            'latest_record' => $records[0] ?? null,
        ];
    }

    // Visa submission
    public function getSubmission(string $submissionId): ?array
    {
        $submissionId = trim($submissionId);

        if ($submissionId === '') {
            throw new InvalidArgumentException(
                'Invalid submission ID.'
            );
        }

        try {
            $response = $this->supabase->asService(
                'GET',
                '/rest/v1/visa_submissions'
                . '?select=id,profile_id,application_id,reference_id,'
                . 'full_name,passport_number,nationality,purpose_of_visit,'
                . 'arrival_date,departure_date,visa_type,'
                . 'visa_effective_date,visa_expiry_date,status,'
                . 'submitted_at,approved_at,approved_by'
                . '&id=eq.' . rawurlencode($submissionId)
                . '&limit=1'
            );

            if (!is_array($response) || empty($response)) {
                return null;
            }

            return $response[0];
        } catch (Throwable $e) {
            throw new RuntimeException(
                'Failed to load visa submission: '
                . $e->getMessage(),
                0,
                $e
            );
        }
    }

    // Planned application information
    public function getPlannedTravelInformation(
        string $applicationId
    ): ?array {
        $applicationId = trim($applicationId);

        if ($applicationId === '') {
            return null;
        }

        try {
            $response = $this->supabase->asService(
                'GET',
                '/rest/v1/travel_information'
                . '?select=airline,flight_number,intended_destination,'
                . 'hotel_name,hotel_address,accommodation_type'
                . '&application_id=eq.' . rawurlencode($applicationId)
                . '&limit=1'
            );

            if (!is_array($response) || empty($response)) {
                return null;
            }

            $planned = $response[0];

            $airline = $this->nullableText(
                $planned['airline'] ?? null
            );

            $flightNumber = $this->nullableText(
                $planned['flight_number'] ?? null
            );

            $planned['inferred_method'] =
                ($airline !== null || $flightNumber !== null)
                    ? 'AIR'
                    : null;

            $referenceParts = [];

            if ($airline !== null) {
                $referenceParts[] = $airline;
            }

            if ($flightNumber !== null) {
                $referenceParts[] = $flightNumber;
            }

            $planned['transport_reference'] =
                empty($referenceParts)
                    ? null
                    : implode(' · ', $referenceParts);

            return $planned;
        } catch (Throwable $e) {
            throw new RuntimeException(
                'Failed to load planned travel information: '
                . $e->getMessage(),
                0,
                $e
            );
        }
    }

    // Actual travel records
    public function getTravelRecords(
        string $submissionId
    ): array {
        $submissionId = trim($submissionId);

        if ($submissionId === '') {
            throw new InvalidArgumentException(
                'Invalid submission ID.'
            );
        }

        try {
            $response = $this->supabase->asService(
                'GET',
                '/rest/v1/visa_travel_records'
                . '?select=*'
                . '&submission_id=eq.' . rawurlencode($submissionId)
                . '&order=actual_entry_at.desc'
            );

            return is_array($response)
                ? $response
                : [];
        } catch (Throwable $e) {
            throw new RuntimeException(
                'Failed to load visa travel records: '
                . $e->getMessage(),
                0,
                $e
            );
        }
    }

    // Current open trip
    public function getCurrentOpenRecord(
        array $records
    ): ?array {
        foreach ($records as $record) {
            if (empty($record['actual_departure_at'])) {
                return $record;
            }
        }

        return null;
    }

    // Dynamic state
    public function calculateTravelState(
        array $submission,
        array $records
    ): string {
        $status = strtolower(
            trim((string)($submission['status'] ?? ''))
        );

        if ($status !== 'approved') {
            return 'NO_TRACKING';
        }

        $expiryValue =
            $submission['visa_expiry_date'] ?? null;

        if (!$expiryValue) {
            return 'EXPIRED';
        }

        try {
            $today = new DateTimeImmutable('today');

            $expiry = new DateTimeImmutable(
                (string)$expiryValue
            );
        } catch (Throwable) {
            return 'EXPIRED';
        }

        $latest = $records[0] ?? null;

        if (is_array($latest)) {
            if (!empty($latest['actual_departure_at'])) {
                $visaType = strtoupper(
                    trim((string)($submission['visa_type'] ?? 'SEV'))
                );

                if ($visaType === 'SEV') {
                    return 'USED';
                }

                if ($today > $expiry) {
                    return 'EXPIRED';
                }

                return 'DEPARTED';
            }

            $stayUntilValue =
                $latest['stay_until_date'] ?? null;

            if (!$stayUntilValue) {
                return 'ACTIVE';
            }

            try {
                $stayUntil = new DateTimeImmutable(
                    (string)$stayUntilValue
                );
            } catch (Throwable) {
                return 'ACTIVE';
            }

            if ($today > $stayUntil) {
                return 'DEPARTURE_NOT_REPORTED';
            }

            $remainingDays =
                $stayUntil->diff($today)->days;

            if ($remainingDays === false) {
                return 'ACTIVE';
            }

            if ($remainingDays <= self::EXPIRING_SOON_DAYS) {
                return 'EXPIRING_SOON';
            }

            return 'ACTIVE';
        }

        if ($today > $expiry) {
            return 'EXPIRED';
        }

        return 'NOT_ENTERED';
    }

    // Remaining permitted stay
    public function calculateRemainingDays(
        array $records
    ): ?int {
        if (empty($records)) {
            return null;
        }

        $latest = $records[0];

        if (!empty($latest['actual_departure_at'])) {
            return 0;
        }

        if (empty($latest['stay_until_date'])) {
            return null;
        }

        try {
            $today = new DateTimeImmutable('today');

            $stayUntil = new DateTimeImmutable(
                (string)$latest['stay_until_date']
            );
        } catch (Throwable) {
            return null;
        }

        if ($today > $stayUntil) {
            return 0;
        }

        $days = $today->diff($stayUntil)->days;

        return $days === false
            ? null
            : (int)$days;
    }

    private function nullableText(mixed $value): ?string
    {
        $text = trim((string)($value ?? ''));

        return $text === ''
            ? null
            : $text;
    }
}
