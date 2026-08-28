<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/config/supabase.php';

final class VisaService
{
    private SupabaseClient $client;

    public function __construct(?SupabaseClient $client = null)
    {
        $this->client = $client ?? new SupabaseClient();
    }

    // ============================================================
    // 公共方法：获取数据
    // ============================================================

    public function getPendingApplications(): array
    {
        try {
            $result = $this->client->asService(
                'GET',
                '/rest/v1/visa_submissions?select=*&status=eq.pending&order=submitted_at.asc'
            );
            return is_array($result) ? $result : [];
        } catch (Throwable $e) {
            error_log('[VisaService] getPendingApplications error: ' . $e->getMessage());
            return [];
        }
    }

    public function getApprovedTourists(): array
    {
        try {
            $result = $this->client->asService(
                'GET',
                '/rest/v1/visa_submissions?select=*,entry_date,stay_until_date,actual_departure_date&status=eq.approved&order=visa_effective_date.desc'
            );
            return is_array($result) ? $result : [];
        } catch (Throwable $e) {
            error_log('[VisaService] getApprovedTourists error: ' . $e->getMessage());
            return [];
        }
    }

    public function getTouristDetails(string $touristId): ?array
    {
        try {
            $result = $this->client->asService(
                'GET',
                '/rest/v1/visa_submissions?select=*,entry_date,stay_until_date,actual_departure_date&id=eq.' . rawurlencode($touristId) . '&limit=1'
            );
            return is_array($result) && !empty($result) ? $result[0] : null;
        } catch (Throwable $e) {
            error_log('[VisaService] getTouristDetails error: ' . $e->getMessage());
            return null;
        }
    }

    public function getStatusHistory(string $touristId): array
    {
        try {
            $result = $this->client->asService(
                'GET',
                '/rest/v1/visa_status_history?select=*&tourist_id=eq.' . rawurlencode($touristId) . '&order=created_at.desc'
            );
            return is_array($result) ? $result : [];
        } catch (Throwable $e) {
            error_log('[VisaService] getStatusHistory error: ' . $e->getMessage());
            return [];
        }
    }

    // ============================================================
    // 统计数据
    // ============================================================

    public function getOverstayCount(): int
    {
        $approved = $this->getApprovedTourists();
        $now = new DateTime();
        $count = 0;
        foreach ($approved as $t) {
            if (!empty($t['stay_until_date'])) {
                $stayUntil = new DateTime($t['stay_until_date']);
                if ($stayUntil < $now) $count++;
            }
        }
        return $count;
    }

    public function getStatusDistribution(): array
    {
        $approved = $this->getApprovedTourists();
        $now = new DateTime();
        $green = $yellow = $red = 0;
        foreach ($approved as $t) {
            if (empty($t['stay_until_date'])) continue;
            $stayUntil = new DateTime($t['stay_until_date']);
            $remaining = $now->diff($stayUntil)->days;
            if ($stayUntil > $now && $remaining > 10) $green++;
            elseif ($stayUntil > $now && $remaining <= 10) $yellow++;
            else $red++;
        }
        return ['green' => $green, 'yellow' => $yellow, 'red' => $red];
    }

    public function getTrendData(): array
    {
        try {
            $end = new DateTime();
            $start = (clone $end)->modify('-7 days');
            $result = $this->client->asService(
                'GET',
                '/rest/v1/visa_submissions?select=submitted_at&status=eq.approved&submitted_at=gte.'
                . rawurlencode($start->format('Y-m-d')) . '&submitted_at=lte.'
                . rawurlencode($end->format('Y-m-d'))
            );
            $data = [];
            if (is_array($result)) {
                $counts = [];
                foreach ($result as $row) {
                    $date = substr($row['submitted_at'] ?? '', 0, 10);
                    $counts[$date] = ($counts[$date] ?? 0) + 1;
                }
                for ($i = 6; $i >= 0; $i--) {
                    $date = (clone $end)->modify("-$i days")->format('Y-m-d');
                    $data[] = ['date' => $date, 'count' => $counts[$date] ?? 0];
                }
            }
            return $data;
        } catch (Throwable $e) {
            error_log('[VisaService] getTrendData error: ' . $e->getMessage());
            return [];
        }
    }

    // ============================================================
    // 判断签证是否有效 (Active/Inactive)
    // ============================================================

    public function isVisaActive(array $tourist): bool
    {
        $now = new DateTime();

        // 1. 签证未生效 → Inactive
        if (!empty($tourist['visa_effective_date'])) {
            $effective = new DateTime($tourist['visa_effective_date']);
            if ($effective > $now) return false;
        }

        // 2. 签证已过期 → Inactive
        if (!empty($tourist['visa_expiry_date'])) {
            $expiry = new DateTime($tourist['visa_expiry_date']);
            if ($expiry < $now) return false;
        }

        // 3. SEV 单次入境：一旦离境即失效
        $visaType = $tourist['visa_type'] ?? 'SEV';
        if ($visaType === 'SEV' && !empty($tourist['actual_departure_date'])) {
            $departure = new DateTime($tourist['actual_departure_date']);
            if ($departure <= $now) return false;
        }

        return true;
    }

    // ============================================================
    // 自动随机生成入境/离境记录
    // ============================================================

    private function generateDemoEntry(string $touristId, array $app, string $approvedDate): bool
    {
        try {
            // 1. 确定实际入境日 (entry_date)
            $arrivalDate = $app['arrival_date'] ?? null;
            $approvedDateTime = new DateTime($approvedDate);
            $entry = null;

            if ($arrivalDate) {
                $entry = new DateTime($arrivalDate);
                $randomDays = random_int(-3, 3);
                $entry->modify("$randomDays days");
                if ($entry < $approvedDateTime) {
                    $entry = clone $approvedDateTime;
                    $entry->modify('+1 day');
                }
            } else {
                $entry = clone $approvedDateTime;
                $entry->modify('+3 days');
            }
            $entryDate = $entry->format('Y-m-d');

            // 2. 确定实际离境日 (actual_departure_date)
            $actualDepartureDate = null;
            $departureDateSubmitted = $app['departure_date'] ?? null;

            if ($departureDateSubmitted) {
                $dep = new DateTime($departureDateSubmitted);
                $randomDays = random_int(-3, 3);
                $dep->modify("$randomDays days");
                if ($dep > $entry) {
                    $actualDepartureDate = $dep->format('Y-m-d');
                }
            }

            if (!$actualDepartureDate && random_int(1, 100) <= 30) {
                $dep = clone $entry;
                $dep->modify('+' . random_int(5, 25) . ' days');
                $actualDepartureDate = $dep->format('Y-m-d');
            }

            // 3. 停留截止日 = 入境日 + 30 天
            $stayUntil = clone $entry;
            $stayUntil->modify('+30 days');
            $stayUntilDate = $stayUntil->format('Y-m-d');

            // 4. 更新数据库
            $updateData = [
                'entry_date' => $entryDate,
                'stay_until_date' => $stayUntilDate,
                'actual_departure_date' => $actualDepartureDate,
            ];

            $this->client->asService(
                'PATCH',
                '/rest/v1/visa_submissions?id=eq.' . rawurlencode($touristId),
                $updateData,
                ['Prefer: return=representation']
            );

            error_log('[VisaService] Demo entry generated for: ' . $touristId .
                      ' entry: ' . $entryDate .
                      ' stay_until: ' . $stayUntilDate .
                      ' actual_departure: ' . ($actualDepartureDate ?? 'none'));
            return true;

        } catch (Throwable $e) {
            error_log('[VisaService] generateDemoEntry error: ' . $e->getMessage());
            return false;
        }
    }

    // ============================================================
    // Approve / Reject
    // ============================================================

    public function approveVisa(string $submissionId, string $effectiveDate, array $admin): bool
    {
        if (empty($submissionId) || empty($effectiveDate)) {
            throw new RuntimeException('Missing submission ID or effective date.');
        }

        $apps = $this->client->asService(
            'GET',
            '/rest/v1/visa_submissions?id=eq.' . rawurlencode($submissionId) . '&limit=1'
        );
        if (empty($apps) || !is_array($apps)) {
            throw new RuntimeException('Application not found.');
        }
        $app = $apps[0];
        if (($app['status'] ?? '') !== 'pending') {
            throw new RuntimeException('Application already processed.');
        }

        $visaType = $app['visa_type'] ?? 'SEV';
        $duration = ($visaType === 'MEV') ? 365 : 90;
        $expiryDate = (new DateTime($effectiveDate))->modify("+$duration days")->format('Y-m-d');

        $updateData = [
            'status' => 'approved',
            'visa_effective_date' => $effectiveDate,
            'visa_expiry_date' => $expiryDate,
            'verified_at' => gmdate('c'),
            'verified_by' => $admin['id'] ?? null,
        ];

        try {
            $updated = $this->client->asService(
                'PATCH',
                '/rest/v1/visa_submissions?id=eq.' . rawurlencode($submissionId),
                $updateData,
                ['Prefer: return=representation']
            );
        } catch (SupabaseApiException $e) {
            throw new RuntimeException('Supabase error: ' . $e->getMessage());
        }

        if (empty($updated)) {
            throw new RuntimeException('Failed to approve visa.');
        }

        // 自动生成模拟入境记录
        $this->generateDemoEntry($submissionId, $app, $effectiveDate);

        // 发送通知
        $profileId = $app['profile_id'] ?? null;
        if ($profileId) {
            try {
                $this->client->asService(
                    'POST',
                    '/rest/v1/notifications',
                    [
                        'user_id' => $profileId,
                        'title' => 'Visa Approved',
                        'message' => 'Your visa application (' . $app['reference_id'] . ') has been approved. Effective date: ' . $effectiveDate,
                        'type' => 'Alert',
                        'is_read' => false,
                        'created_at' => gmdate('c')
                    ]
                );
            } catch (Throwable $e) {
                error_log('[VisaService] Notification failed: ' . $e->getMessage());
            }
        }

        return true;
    }

    public function rejectVisa(string $submissionId, string $reason, array $admin): bool
    {
        if (empty($submissionId)) {
            throw new RuntimeException('Missing submission ID.');
        }

        $apps = $this->client->asService(
            'GET',
            '/rest/v1/visa_submissions?id=eq.' . rawurlencode($submissionId) . '&limit=1'
        );
        if (empty($apps)) {
            throw new RuntimeException('Application not found.');
        }
        $app = $apps[0];
        if (($app['status'] ?? '') !== 'pending') {
            throw new RuntimeException('Application already processed.');
        }

        $updateData = [
            'status' => 'rejected',
            'rejection_reason' => $reason ?: null,
            'verified_at' => gmdate('c'),
            'verified_by' => $admin['id'] ?? null,
        ];

        try {
            $updated = $this->client->asService(
                'PATCH',
                '/rest/v1/visa_submissions?id=eq.' . rawurlencode($submissionId),
                $updateData,
                ['Prefer: return=representation']
            );
        } catch (SupabaseApiException $e) {
            throw new RuntimeException('Supabase error: ' . $e->getMessage());
        }

        if (empty($updated)) {
            throw new RuntimeException('Failed to reject visa.');
        }

        $profileId = $app['profile_id'] ?? null;
        if ($profileId) {
            try {
                $this->client->asService(
                    'POST',
                    '/rest/v1/notifications',
                    [
                        'user_id' => $profileId,
                        'title' => 'Visa Rejected',
                        'message' => 'Your visa application (' . $app['reference_id'] . ') has been rejected.' . ($reason ? ' Reason: ' . $reason : ''),
                        'type' => 'Alert',
                        'is_read' => false,
                        'created_at' => gmdate('c')
                    ]
                );
            } catch (Throwable $e) {
                error_log('[VisaService] Notification failed: ' . $e->getMessage());
            }
        }

        return true;
    }
}