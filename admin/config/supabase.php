<?php
declare(strict_types=1);

require_once __DIR__ . '/env.php';

final class SupabaseApiException extends RuntimeException
{
    public function __construct(
        string $message,
        public readonly int $statusCode,
        public readonly string $responseBody = ''
    ) {
        parent::__construct($message, $statusCode);
    }
}

final class SupabaseClient
{
    private string $url;
    private string $anonKey;
    private string $serviceRoleKey;

    public function __construct()
    {
        // Put values in admin/.env. Env::required receives variable NAMES.
        $configuredUrl = rtrim(Env::required('SUPABASE_URL'), '/');
        $this->url = preg_replace(
            '#/(?:rest|auth|storage)/v1$#',
            '',
            $configuredUrl
        ) ?? $configuredUrl;
        $this->anonKey = Env::required('SUPABASE_ANON_KEY');
        $this->serviceRoleKey = Env::required('SUPABASE_SERVICE_ROLE_KEY');
    }

    /** @return array<string, mixed>|list<mixed> */
    public function anonymous(
        string $method,
        string $path,
        ?array $body = null,
        array $extraHeaders = []
    ): array {
        return $this->request(
            $method,
            $path,
            $body,
            $this->anonKey,
            $this->anonKey,
            $extraHeaders
        );
    }

    /** @return array<string, mixed>|list<mixed> */
    public function asUser(
        string $method,
        string $path,
        string $accessToken,
        ?array $body = null,
        array $extraHeaders = []
    ): array {
        return $this->request(
            $method,
            $path,
            $body,
            $accessToken,
            $this->anonKey,
            $extraHeaders
        );
    }

    /** @return array<string, mixed>|list<mixed> */
    public function asService(
        string $method,
        string $path,
        ?array $body = null,
        array $extraHeaders = []
    ): array {
        return $this->request(
            $method,
            $path,
            $body,
            $this->serviceRoleKey,
            $this->serviceRoleKey,
            $extraHeaders
        );
    }

    /** @return array<string, mixed>|list<mixed> */
    private function request(
        string $method,
        string $path,
        ?array $body,
        string $bearerToken,
        string $apiKey,
        array $extraHeaders
    ): array {
        $handle = curl_init($this->url . '/' . ltrim($path, '/'));
        if ($handle === false) {
            throw new RuntimeException('Could not initialize the Supabase request.');
        }

        $headers = array_merge([
            'apikey: ' . $apiKey,
            'Authorization: Bearer ' . $bearerToken,
            'Accept: application/json',
            'Content-Type: application/json',
        ], $extraHeaders);

        $options = [
            CURLOPT_CUSTOMREQUEST => strtoupper($method),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => $headers,
            CURLOPT_CONNECTTIMEOUT => 10,
            CURLOPT_TIMEOUT => 30,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_FOLLOWLOCATION => false,
        ];
        if ($body !== null) {
            $options[CURLOPT_POSTFIELDS] = json_encode($body, JSON_THROW_ON_ERROR);
        }
        curl_setopt_array($handle, $options);

        $response = curl_exec($handle);
        $status = (int) curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
        $curlError = curl_error($handle);
        curl_close($handle);

        if ($response === false) {
            throw new RuntimeException(
                $curlError !== '' ? $curlError : 'Supabase request failed.'
            );
        }
        if ($status < 200 || $status >= 300) {
            $message = 'Supabase rejected the request.';
            $decodedError = json_decode($response, true);
            if (is_array($decodedError)) {
                $message = (string) (
                    $decodedError['msg']
                    ?? $decodedError['message']
                    ?? $decodedError['error_description']
                    ?? $message
                );
            }
            throw new SupabaseApiException($message, $status, $response);
        }
        if ($response === '' || $status === 204) {
            return [];
        }

        $decoded = json_decode($response, true, 512, JSON_THROW_ON_ERROR);
        return is_array($decoded) ? $decoded : [];
    }
}
