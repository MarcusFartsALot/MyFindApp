<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/config/supabase.php';
require_once __DIR__ . '/email_service.php';

final class ApplicationService
{
    private SupabaseClient $client;

    public function __construct(?SupabaseClient $client = null)
    {
        $this->client = $client ?? new SupabaseClient();
    }

    /** @return list<array<string, mixed>> */
    public function pendingApplications(): array
    {
        $applications = array_merge(
            $this->pendingRoleRecords('citizen'),
            $this->pendingRoleRecords('tourist')
        );
        usort($applications, static function (array $left, array $right): int {
            return strtotime((string) $left['submitted_at'])
                <=> strtotime((string) $right['submitted_at']);
        });
        return $applications;
    }

    public function pendingCount(): int
    {
        return count($this->pendingApplications());
    }

    /** @return array<string, mixed> */
    public function find(string $profileId): array
    {
        $profileRows = $this->client->asService(
            'GET',
            '/rest/v1/profiles?select=*&id=eq.' . rawurlencode($profileId) . '&limit=1'
        );
        $profile = $profileRows[0] ?? null;
        if (!is_array($profile)) {
            throw new RuntimeException('Registration application not found.');
        }

        $role = $profile['role'] ?? null;
        if ($role !== 'citizen' && $role !== 'tourist') {
            throw new RuntimeException('Application has an invalid role.');
        }
        $table = $this->roleTable($role);
        $roleRows = $this->client->asService(
            'GET',
            '/rest/v1/' . $table . '?select=*&profile_id=eq.'
            . rawurlencode($profileId) . '&limit=1'
        );
        $roleRecord = $roleRows[0] ?? null;
        if (!is_array($roleRecord)) {
            throw new RuntimeException('Registration application details are incomplete.');
        }

        return $this->combineApplication($profile, $roleRecord, $role);
    }

    public function signedDocumentUrl(string $path, int $expiresIn = 300): string
    {
        $encodedPath = implode('/', array_map('rawurlencode', explode('/', $path)));
        $result = $this->client->asService(
            'POST',
            '/storage/v1/object/sign/registration-documents/' . $encodedPath,
            ['expiresIn' => $expiresIn]
        );
        $signedUrl = $result['signedURL'] ?? $result['signedUrl'] ?? null;
        if (!is_string($signedUrl) || $signedUrl === '') {
            throw new RuntimeException('Could not create a secure document link.');
        }
        if (str_starts_with($signedUrl, 'http://') || str_starts_with($signedUrl, 'https://')) {
            return $signedUrl;
        }
        return rtrim(Env::required('SUPABASE_URL'), '/')
            . '/storage/v1/' . ltrim($signedUrl, '/');
    }

    /** @param array<string, mixed> $admin */
    public function approve(string $profileId, array $admin): bool
    {
        $application = $this->find($profileId);
        $this->assertPendingAndValid($application);

        $adminId = $admin['id'] ?? null;
        if (!is_string($adminId)) {
            throw new RuntimeException('Administrator profile is invalid.');
        }

        $role = (string) $application['requested_role'];
        $roleTable = $this->roleTable($role);
        $email = strtolower(trim((string) $application['email']));
        $fullName = trim((string) $application['full_name']);
        $temporaryPassword = $this->temporaryPassword($application);
        $authUserId = null;
        $profileLinked = false;
        $committed = false;
        try {
            $createdUser = $this->client->asService(
                'POST',
                '/auth/v1/admin/users',
                [
                    'email' => $email,
                    'password' => $temporaryPassword,
                    'email_confirm' => true,
                    'user_metadata' => [
                        'full_name' => $fullName,
                        'role' => $role,
                        'application_profile_id' => $profileId,
                        'module' => 'M400',
                        'password_setup_required' => true,
                    ],
                ]
            );
            $wrappedData = is_array($createdUser['data'] ?? null)
                ? $createdUser['data']
                : [];
            $user = is_array($createdUser['user'] ?? null)
                ? $createdUser['user']
                : (is_array($wrappedData['user'] ?? null)
                    ? $wrappedData['user']
                    : $createdUser);
            $authUserId = $user['id'] ?? null;
            if (!is_string($authUserId)) {
                throw new RuntimeException(
                    'Supabase Auth returned incomplete account data.'
                );
            }

            $updatedProfiles = $this->client->asService(
                'PATCH',
                '/rest/v1/profiles?id=eq.' . rawurlencode($profileId)
                . '&auth_id=is.null',
                ['auth_id' => $authUserId, 'updated_at' => gmdate('c')],
                ['Prefer: return=representation']
            );
            if (!isset($updatedProfiles[0])) {
                throw new RuntimeException('This application has already been processed.');
            }
            $profileLinked = true;

            $updatedRole = $this->client->asService(
                'PATCH',
                '/rest/v1/' . $roleTable . '?profile_id=eq.'
                . rawurlencode($profileId) . '&verification_status=eq.pending',
                [
                    'verification_status' => 'approved',
                    'rejection_reason' => null,
                    'verified_at' => gmdate('c'),
                    'verified_by' => $adminId,
                ],
                ['Prefer: return=representation']
            );
            if (!isset($updatedRole[0])) {
                throw new RuntimeException('This application has already been processed.');
            }
            $committed = true;

            return true;
        } catch (Throwable $error) {
            if (!$committed && is_string($authUserId)) {
                if ($profileLinked) {
                    try {
                        $this->client->asService(
                            'PATCH',
                            '/rest/v1/profiles?id=eq.' . rawurlencode($profileId)
                            . '&auth_id=eq.' . rawurlencode($authUserId),
                            ['auth_id' => null, 'updated_at' => gmdate('c')]
                        );
                    } catch (Throwable) {
                        // Continue attempting to remove the incomplete Auth user.
                    }
                }
                try {
                    $this->client->asService(
                        'DELETE',
                        '/auth/v1/admin/users/' . rawurlencode($authUserId)
                    );
                } catch (Throwable) {
                    // Preserve the original approval error for the administrator.
                }
            }
            throw $error;
        }
    }

    /** @param array<string, mixed> $admin */
    public function reject(string $profileId, array $admin, ?string $reason): bool
    {
        $application = $this->find($profileId);
        $this->assertPendingAndValid($application);
        $adminId = $admin['id'] ?? null;
        if (!is_string($adminId)) {
            throw new RuntimeException('Administrator profile is invalid.');
        }

        $reason = $reason === null || trim($reason) === '' ? null : trim($reason);
        if ($reason !== null && mb_strlen($reason) > 1000) {
            throw new RuntimeException('Rejection reason must be 1,000 characters or fewer.');
        }
        $emailService = new EmailService();

        $validation = $this->client->asService(
            'POST',
            '/rest/v1/rpc/module400_delete_pending_application',
            ['p_profile_id' => $profileId, 'p_validate_only' => true]
        );
        if (($validation['valid'] ?? null) !== true) {
            throw new RuntimeException('The application could not be validated for deletion.');
        }

        $this->deleteRegistrationDocuments($application);
        $deletion = $this->client->asService(
            'POST',
            '/rest/v1/rpc/module400_delete_pending_application',
            ['p_profile_id' => $profileId, 'p_validate_only' => false]
        );
        if (($deletion['deleted'] ?? null) !== true) {
            throw new RuntimeException('The rejected application was not deleted.');
        }

        return $emailService->sendRejection(
            (string) $application['email'],
            (string) $application['full_name'],
            $reason
        );
    }

    /** @param array<string, mixed> $application */
    private function deleteRegistrationDocuments(array $application): void
    {
        $profileId = (string) ($application['id'] ?? '');
        $role = (string) ($application['requested_role'] ?? '');
        $pattern = $role === 'citizen'
            ? '#^citizens/' . preg_quote($profileId, '#')
                . '/mykad_(?:front|back)\.(?:jpg|jpeg|png)$#'
            : '#^tourists/' . preg_quote($profileId, '#')
                . '/passport_(?:front|back)\.(?:jpg|jpeg|png)$#';
        $paths = array_values(array_filter([
            $application['document_path'] ?? null,
            $application['document_back_path'] ?? null,
        ], static fn (mixed $path): bool => is_string($path) && $path !== ''));

        if ($paths === []) {
            throw new RuntimeException('Registration document paths are missing.');
        }
        foreach ($paths as $path) {
            if (preg_match($pattern, $path) !== 1) {
                throw new RuntimeException('Registration document path is invalid.');
            }
        }

        $this->client->asService(
            'DELETE',
            '/storage/v1/object/registration-documents',
            ['prefixes' => array_values(array_unique($paths))]
        );
    }

    /** @return list<array<string, mixed>> */
    private function pendingRoleRecords(string $role): array
    {
        $table = $this->roleTable($role);
        $profileRelationship = $table . '_profile_id_fkey';
        $rows = $this->client->asService(
            'GET',
            '/rest/v1/' . $table
            . '?select=*,profiles!' . $profileRelationship . '!inner(*)'
            . '&verification_status=eq.pending'
            . '&profiles.role=eq.' . rawurlencode($role)
        );

        $applications = [];
        foreach ($rows as $row) {
            if (!is_array($row) || !is_array($row['profiles'] ?? null)) {
                continue;
            }
            $applications[] = $this->combineApplication(
                $row['profiles'],
                $row,
                $role
            );
        }
        return $applications;
    }

    /**
     * @param array<string, mixed> $profile
     * @param array<string, mixed> $roleRecord
     * @return array<string, mixed>
     */
    private function combineApplication(
        array $profile,
        array $roleRecord,
        string $role
    ): array {
        $isCitizen = $role === 'citizen';
        return array_merge($profile, $roleRecord, [
            'id' => $profile['id'],
            'requested_role' => $role,
            'identity_number' => $isCitizen
                ? $roleRecord['ic_number']
                : $roleRecord['passport_number'],
            'document_type' => $isCitizen ? 'mykad' : 'passport',
            'document_path' => $isCitizen
                ? $roleRecord['ic_front_url']
                : $roleRecord['passport_front_url'],
            'document_back_path' => $isCitizen
                ? $roleRecord['ic_back_url']
                : ($roleRecord['passport_back_url'] ?? null),
            'submitted_at' => $profile['created_at'],
            'status' => $roleRecord['verification_status'],
        ]);
    }

    /** @param array<string, mixed> $application */
    private function assertPendingAndValid(array $application): void
    {
        if (($application['auth_id'] ?? null) !== null) {
            throw new RuntimeException('This application already has an authentication account.');
        }
        if (($application['status'] ?? null) !== 'pending') {
            throw new RuntimeException('This application has already been processed.');
        }
        $role = $application['requested_role'] ?? null;
        if ($role !== 'citizen' && $role !== 'tourist') {
            throw new RuntimeException('Application has an invalid role.');
        }
        if ($role === 'citizen') {
            if (empty($application['ic_front_url']) || empty($application['ic_back_url'])) {
                throw new RuntimeException('Citizen application is missing a MyKad image.');
            }
            return;
        }

        if (
            empty($application['passport_front_url'])
            || empty($application['passport_expiry_date'])
            || empty($application['passport_issuing_country'])
        ) {
            throw new RuntimeException('Tourist application is missing passport details.');
        }
        $expiryTimestamp = strtotime((string) $application['passport_expiry_date'] . ' 23:59:59 UTC');
        if ($expiryTimestamp === false || $expiryTimestamp <= time()) {
            throw new RuntimeException('The submitted passport has expired.');
        }
    }

    private function roleTable(string $role): string
    {
        return match ($role) {
            'citizen' => 'citizens',
            'tourist' => 'tourists',
            default => throw new RuntimeException('Application has an invalid role.'),
        };
    }

    /** @param array<string, mixed> $application */
    private function temporaryPassword(array $application): string
    {
        $identity = strtoupper((string) preg_replace(
            '/[^A-Z0-9]/',
            '',
            (string) ($application['identity_number'] ?? '')
        ));
        $role = $application['requested_role'] ?? null;

        if ($role === 'citizen' && preg_match('/^[0-9]{12}$/', $identity) !== 1) {
            throw new RuntimeException('The application has an invalid IC number.');
        }
        if (
            $role === 'tourist'
            && preg_match('/^[A-Z0-9]{6,20}$/', $identity) !== 1
        ) {
            throw new RuntimeException(
                'The passport number must contain 6-20 letters or numbers.'
            );
        }

        return $identity;
    }

    // ============================================================
    // PROFILE METHODS (for admin profile settings)
    // ============================================================

    /**
     * Get admin profile by ID
     * 
     * @param string $profileId The admin profile ID
     * @return array<string, mixed>|null
     */
    public function getAdminById(string $profileId): ?array
    {
        try {
            $profiles = $this->client->asService(
                'GET',
                '/rest/v1/profiles?select=*&id=eq.' . rawurlencode($profileId) . '&limit=1'
            );
            
            return (is_array($profiles) && count($profiles) > 0) ? $profiles[0] : null;
        } catch (Throwable $e) {
            error_log('Get admin by ID error: ' . $e->getMessage());
            return null;
        }
    }

    /**
     * Update admin profile information (full_name, phone_number, nationality)
     * 
     * @param string $profileId The admin profile ID
     * @param array<string, string> $data Profile data (full_name, phone_number, nationality)
     * @return bool
     */
    public function updateAdminProfile(string $profileId, array $data): bool
    {
        try {
            $updateData = [];
            $allowedFields = ['full_name', 'phone_number', 'nationality'];

            foreach ($allowedFields as $field) {
                if (array_key_exists($field, $data)) {
                    $value = trim((string) $data[$field]);
                    if ($value === '') {
                        throw new RuntimeException(ucfirst(str_replace('_', ' ', $field)) . ' cannot be empty.');
                    }
                    $updateData[$field] = $value;
                }
            }

            if (empty($updateData)) {
                return false;
            }

            $updateData['updated_at'] = gmdate('c');

            $result = $this->client->asService(
                'PATCH',
                '/rest/v1/profiles?id=eq.' . rawurlencode($profileId),
                $updateData,
                ['Prefer: return=representation']
            );

            return isset($result[0]);
        } catch (Throwable $e) {
            error_log('Update admin profile error: ' . $e->getMessage());
            throw $e;
        }
    }

    /**
     * Update admin password with current password verification
     * 
     * @param string $authId The auth user ID
     * @param string $email Admin email
     * @param string $currentPassword Current password for verification
     * @param string $newPassword New password
     * @return bool
     */
    public function updateAdminPasswordWithVerification(
        string $authId,
        string $email,
        string $currentPassword,
        string $newPassword
    ): bool {
        try {
            // First, verify the current password
            $verifyResult = $this->client->anonymous(
                'POST',
                '/auth/v1/token?grant_type=password',
                [
                    'email' => strtolower(trim($email)),
                    'password' => $currentPassword
                ]
            );

            // If verification fails, return false
            if (!isset($verifyResult['access_token'])) {
                return false;
            }

            // Update the password
            $this->client->asService(
                'PUT',
                '/auth/v1/admin/users/' . rawurlencode($authId),
                ['password' => $newPassword]
            );
            return true;
        } catch (Throwable $e) {
            error_log('Update admin password with verification error: ' . $e->getMessage());
            return false;
        }
    }

    /**
     * Upload admin profile image to Supabase Storage
     * 
     * @param string $profileId The admin profile ID
     * @param string $tmpPath Temporary file path
     * @param string $filename Generated filename
     * @param string $mimeType MIME type of the file
     * @return bool
     */
    public function uploadAdminProfileImage(
        string $profileId,
        string $tmpPath,
        string $filename,
        string $mimeType
    ): bool {
        try {
            // Get existing image to delete old one
            $admin = $this->getAdminById($profileId);
            if ($admin && !empty($admin['profile_image'])) {
                $this->removeAdminProfileImage($profileId);
            }

            // Get Supabase configuration
            $supabaseUrl = rtrim(Env::required('SUPABASE_URL'), '/');
            $supabaseKey = Env::required('SUPABASE_SERVICE_ROLE_KEY');
            
            // Verify the key is valid format
            if (!str_starts_with($supabaseKey, 'eyJ')) {
                throw new RuntimeException('Invalid service role key format. It should start with "eyJ".');
            }

            // Use the 'admin' bucket
            $bucket = 'admin';
            
            $encodedFilename = rawurlencode($filename);
            $path = 'profiles/' . $encodedFilename;
            
            $fileContent = file_get_contents($tmpPath);
            if ($fileContent === false) {
                throw new RuntimeException('Failed to read uploaded file.');
            }

            $url = $supabaseUrl . '/storage/v1/object/' . $bucket . '/' . $path;

            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, $url);
            curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PUT');
            curl_setopt($ch, CURLOPT_POSTFIELDS, $fileContent);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_TIMEOUT, 30);
            curl_setopt($ch, CURLOPT_HTTPHEADER, [
                'Content-Type: ' . $mimeType,
                'Authorization: Bearer ' . $supabaseKey,
                'apikey: ' . $supabaseKey,
            ]);

            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $curlError = curl_error($ch);
            curl_close($ch);

            if ($httpCode !== 200 && $httpCode !== 201) {
                $errorMsg = 'Storage upload failed with status: ' . $httpCode;
                $responseData = json_decode($response, true);
                if (isset($responseData['message'])) {
                    $errorMsg .= ' - ' . $responseData['message'];
                }
                throw new RuntimeException($errorMsg);
            }

            // Update database with image URL
            $imageUrl = $supabaseUrl . '/storage/v1/object/public/' . $bucket . '/' . $path;
            return $this->updateAdminProfileImageUrl($profileId, $imageUrl);
        } catch (Throwable $e) {
            error_log('Upload admin image error: ' . $e->getMessage());
            throw $e;
        }
    }

    /**
     * Update admin profile image URL in database
     * 
     * @param string $profileId The admin profile ID
     * @param string $imageUrl The image URL
     * @return bool
     */
    private function updateAdminProfileImageUrl(string $profileId, string $imageUrl): bool
    {
        try {
            $result = $this->client->asService(
                'PATCH',
                '/rest/v1/profiles?id=eq.' . rawurlencode($profileId),
                [
                    'profile_image' => $imageUrl,
                    'updated_at' => gmdate('c')
                ],
                ['Prefer: return=representation']
            );

            return isset($result[0]);
        } catch (Throwable $e) {
            error_log('Update admin profile image URL error: ' . $e->getMessage());
            return false;
        }
    }

    /**
     * Remove admin profile image
     * 
     * @param string $profileId The admin profile ID
     * @return bool
     */
    public function removeAdminProfileImage(string $profileId): bool
    {
        try {
            $admin = $this->getAdminById($profileId);
            if (!$admin || empty($admin['profile_image'])) {
                return true;
            }

            // Extract path from URL
            $imageUrl = (string) $admin['profile_image'];
            $supabaseUrl = rtrim(Env::required('SUPABASE_URL'), '/');
            $supabaseKey = Env::required('SUPABASE_SERVICE_ROLE_KEY');
            $bucket = 'admin';
            $pattern = '#^' . preg_quote($supabaseUrl . '/storage/v1/object/public/' . $bucket . '/', '#') . '#';
            $path = preg_replace($pattern, '', $imageUrl);

            if (empty($path)) {
                return true;
            }

            $url = $supabaseUrl . '/storage/v1/object/' . $bucket . '/' . $path;

            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, $url);
            curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'DELETE');
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_HTTPHEADER, [
                'Authorization: Bearer ' . $supabaseKey,
                'apikey: ' . $supabaseKey,
            ]);

            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $curlError = curl_error($ch);
            curl_close($ch);

            if ($httpCode !== 200 && $httpCode !== 204 && $httpCode !== 404) {
                error_log('Supabase delete error - HTTP: ' . $httpCode . ' Response: ' . $response);
                return false;
            }

            // Update database to remove the image URL
            $result = $this->client->asService(
                'PATCH',
                '/rest/v1/profiles?id=eq.' . rawurlencode($profileId),
                [
                    'profile_image' => null,
                    'updated_at' => gmdate('c')
                ],
                ['Prefer: return=representation']
            );

            return isset($result[0]);
        } catch (Throwable $e) {
            error_log('Remove admin image error: ' . $e->getMessage());
            return false;
        }
    }
}