<?php

declare(strict_types=1);

require_once __DIR__ . '/../config/supabase.php';

class VisaService
{

    public function __construct(
        private SupabaseClient $supabase
    ) {
    }

    public function getPendingApplications(): array
    {
        try {
            $response = $this->supabase->asService(
                'GET',
                '/rest/v1/visa_submissions'
                . '?select=*'
                . '&status=eq.pending'
                . '&order=submitted_at.desc'
            );

            return is_array($response) ? $response : [];
        } catch (Throwable $e) {
            throw new RuntimeException(
                'Failed to load pending visa applications: '
                . $e->getMessage(),
                0,
                $e
            );
        }
    }

    public function getApprovedTourists(): array
    {
        try {
            $response = $this->supabase->asService(
                'GET',
                '/rest/v1/visa_submissions'
                . '?select=*'
                . '&status=eq.approved'
                . '&order=visa_effective_date.desc'
            );

            return is_array($response)
                ? $response
                : [];
        } catch (Throwable $e) {
            throw new RuntimeException(
                'Failed to load approved tourists: '
                . $e->getMessage(),
                0,
                $e
            );
        }
    }

    public function getTouristDetails(
        string $submissionId
    ): ?array {
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
                . '?select=*'
                . '&id=eq.' . rawurlencode($submissionId)
                . '&limit=1'
            );

            if (!is_array($response) || empty($response)) {
                return null;
            }

            return $response[0];
        } catch (Throwable $e) {
            throw new RuntimeException(
                'Failed to load tourist details: '
                . $e->getMessage(),
                0,
                $e
            );
        }
    }

    public function getStatusHistory(
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
                '/rest/v1/visa_status_history'
                . '?select=*'
                . '&submission_id=eq.'
                . rawurlencode($submissionId)
                . '&order=created_at.desc'
            );

            return is_array($response) ? $response : [];
        } catch (Throwable $e) {
            throw new RuntimeException(
                'Failed to load visa status history: '
                . $e->getMessage(),
                0,
                $e
            );
        }
    }

    public function getTrendData(): array
    {
        try {
            $end = new DateTimeImmutable('today');
            $start = $end->modify('-6 days');

            $response = $this->supabase->asService(
                'GET',
                '/rest/v1/visa_submissions'
                . '?select=submitted_at,status'
                . '&submitted_at=gte.'
                . rawurlencode(
                    $start->format('Y-m-d') . 'T00:00:00'
                )
                . '&submitted_at=lte.'
                . rawurlencode(
                    $end->format('Y-m-d') . 'T23:59:59'
                )
            );

            $counts = [];

            for ($i = 0; $i < 7; $i++) {
                $date = $start
                    ->modify("+$i days")
                    ->format('Y-m-d');

                $counts[$date] = [
                    'total' => 0,
                    'approved' => 0,
                    'rejected' => 0,
                    'pending' => 0,
                    'cancelled' => 0,
                ];
            }

            if (is_array($response)) {
                foreach ($response as $row) {
                    $date = substr(
                        (string)($row['submitted_at'] ?? ''),
                        0,
                        10
                    );

                    if (!isset($counts[$date])) {
                        continue;
                    }

                    $counts[$date]['total']++;

                    $status = strtolower(
                        trim((string)($row['status'] ?? ''))
                    );

                    if (isset($counts[$date][$status])) {
                        $counts[$date][$status]++;
                    }
                }
            }

            $data = [];

            foreach ($counts as $date => $count) {
                $data[] = [
                    'date' => $date,
                    'total' => $count['total'],
                    'approved' => $count['approved'],
                    'rejected' => $count['rejected'],
                    'pending' => $count['pending'],
                    'cancelled' => $count['cancelled'],
                ];
            }

            return $data;
        } catch (Throwable $e) {
            throw new RuntimeException(
                'Failed to load visa trend data: '
                . $e->getMessage(),
                0,
                $e
            );
        }
    }

    public function isVisaActive(array $tourist): bool
    {
        if (
            strtolower(
                trim((string)($tourist['status'] ?? ''))
            ) !== 'approved'
        ) {
            return false;
        }

        $today = new DateTimeImmutable('today');

        $effectiveDate =
            $tourist['visa_effective_date'] ?? null;

        $expiryDate =
            $tourist['visa_expiry_date'] ?? null;

        if (!$effectiveDate || !$expiryDate) {
            return false;
        }

        try {
            $effective = new DateTimeImmutable(
                (string)$effectiveDate
            );

            $expiry = new DateTimeImmutable(
                (string)$expiryDate
            );
        } catch (Throwable) {
            return false;
        }

        if ($today < $effective || $today > $expiry) {
            return false;
        }

        return true;
    }

    public function approveVisa(
        string $submissionId,
        array $admin
    ): bool {
        $submissionId = trim($submissionId);

        if ($submissionId === '') {
            throw new InvalidArgumentException(
                'Invalid submission ID.'
            );
        }

        if (empty($admin)) {
            throw new RuntimeException(
                'Unable to identify the administrator.'
            );
        }

        $adminId = trim(
            (string)($admin['id'] ?? '')
        );

        if ($adminId === '') {
            throw new RuntimeException(
                'Unable to identify the administrator.'
            );
        }

        $submission =
            $this->getTouristDetails($submissionId);

        if (!$submission) {
            throw new RuntimeException(
                'Visa submission not found.'
            );
        }

        if (
            strtolower(
                (string)($submission['status'] ?? '')
            ) !== 'pending'
        ) {
            throw new RuntimeException(
                'Only pending visa applications can be approved.'
            );
        }

        $visaType = strtoupper(
            trim((string)($submission['visa_type'] ?? ''))
        );

        if (!in_array($visaType, ['SEV', 'MEV'], true)) {
            throw new RuntimeException(
                'Invalid visa type. Visa type must be SEV or MEV.'
            );
        }

        $effectiveDate = new DateTimeImmutable('today');

        $validityDays = $visaType === 'SEV'
            ? 90
            : 365;

        $expiryDate = $effectiveDate->modify(
            '+' . $validityDays . ' days'
        );

        $approvedAt = new DateTimeImmutable();

        try {
            $updated = $this->supabase->asService(
                'PATCH',
                '/rest/v1/visa_submissions'
                . '?id=eq.' . rawurlencode($submissionId)
                . '&status=eq.pending',
                [
                    'status' => 'approved',
                    'visa_type' => $visaType,
                    'visa_effective_date' =>
                        $effectiveDate->format('Y-m-d'),
                    'visa_expiry_date' =>
                        $expiryDate->format('Y-m-d'),
                    'approved_at' =>
                        $approvedAt->format(
                            DateTimeInterface::ATOM
                        ),
                    'approved_by' => $adminId,
                ],
                ['Prefer: return=representation']
            );

            if (empty($updated)) {
                throw new RuntimeException(
                    'Failed to approve visa application.'
                );
            }
        } catch (SupabaseApiException $e) {
            throw new RuntimeException(
                'Failed to approve visa application: '
                . $e->getMessage(),
                0,
                $e
            );
        }

        $this->sendNotification(
            $submission['profile_id'] ?? null,
            'Visa Application Approved',
            'Your visa application ('
            . ($submission['reference_id'] ?? '')
            . ') has been approved. Effective date: '
            . $effectiveDate->format('Y-m-d')
            . '. Visa type: '
            . $visaType
            . '.',
            'Notification'
        );

        return true;
    }

    public function rejectVisa(
        string $submissionId,
        string $reason,
        array $admin
    ): bool {
        $submissionId = trim($submissionId);
        $reason = trim($reason);

        if ($submissionId === '') {
            throw new InvalidArgumentException(
                'Invalid submission ID.'
            );
        }

        if ($reason === '') {
            throw new InvalidArgumentException(
                'Rejection reason is required.'
            );
        }

        if (empty($admin)) {
            throw new RuntimeException(
                'Unable to identify the administrator.'
            );
        }

        $adminId = trim(
            (string)($admin['id'] ?? '')
        );

        if ($adminId === '') {
            throw new RuntimeException(
                'Unable to identify the administrator.'
            );
        }

        $submission =
            $this->getTouristDetails($submissionId);

        if (!$submission) {
            throw new RuntimeException(
                'Visa submission not found.'
            );
        }

        if (
            strtolower(
                (string)($submission['status'] ?? '')
            ) !== 'pending'
        ) {
            throw new RuntimeException(
                'Only pending visa applications can be rejected.'
            );
        }

        try {
            $updated = $this->supabase->asService(
                'PATCH',
                '/rest/v1/visa_submissions'
                . '?id=eq.' . rawurlencode($submissionId)
                . '&status=eq.pending',
                [
                    'status' => 'rejected',
                    'rejection_reason' => $reason,
                ],
                ['Prefer: return=representation']
            );

            if (empty($updated)) {
                throw new RuntimeException(
                    'Failed to reject visa application.'
                );
            }
        } catch (SupabaseApiException $e) {
            throw new RuntimeException(
                'Failed to reject visa application: '
                . $e->getMessage(),
                0,
                $e
            );
        }

        $this->sendNotification(
            $submission['profile_id'] ?? null,
            'Visa Application Rejected',
            'Your visa application ('
            . ($submission['reference_id'] ?? '')
            . ') has been rejected.',
            'Alert'
        );

        return true;
    }

    public function cancelPendingVisa(
        string $submissionId,
        string $profileId
    ): bool {
        $submissionId = trim($submissionId);
        $profileId = trim($profileId);

        if (
            $submissionId === ''
            || $profileId === ''
        ) {
            throw new InvalidArgumentException(
                'Invalid cancellation information.'
            );
        }

        $submission =
            $this->getTouristDetails($submissionId);

        if (!$submission) {
            throw new RuntimeException(
                'Visa submission not found.'
            );
        }

        if (
            (string)($submission['profile_id'] ?? '')
            !== $profileId
        ) {
            throw new RuntimeException(
                'You are not authorized to cancel this application.'
            );
        }

        if (
            strtolower(
                (string)($submission['status'] ?? '')
            ) !== 'pending'
        ) {
            throw new RuntimeException(
                'Only pending visa applications can be cancelled.'
            );
        }

        try {
            $updated = $this->supabase->asService(
                'PATCH',
                '/rest/v1/visa_submissions'
                . '?id=eq.' . rawurlencode($submissionId)
                . '&profile_id=eq.'
                . rawurlencode($profileId)
                . '&status=eq.pending',
                [
                    'status' => 'cancelled',
                ],
                ['Prefer: return=representation']
            );

            if (empty($updated)) {
                throw new RuntimeException(
                    'The pending application is no longer available '
                    . 'for cancellation.'
                );
            }

            return true;
        } catch (SupabaseApiException $e) {
            throw new RuntimeException(
                'Failed to cancel visa application: '
                . $e->getMessage(),
                0,
                $e
            );
        }
    }

    private function sendNotification(
        ?string $profileId,
        string $title,
        string $message,
        string $type
    ): void {
        if (!$profileId) {
            return;
        }

        try {
            $this->supabase->asService(
                'POST',
                '/rest/v1/notifications',
                [
                    'user_id' => $profileId,
                    'title' => $title,
                    'message' => $message,
                    'type' => $type,
                    'is_read' => false,
                ],
                ['Prefer: return=minimal']
            );
        } catch (Throwable $e) {
            error_log(
                '[VisaService] Notification failed: '
                . $e->getMessage()
            );
        }
    }
}
