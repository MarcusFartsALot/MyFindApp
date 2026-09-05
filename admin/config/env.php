<?php
declare(strict_types=1);

final class Env
{
    private static bool $loaded = false;
    /** @var array<string, string> */
    private static array $values = [];

    public static function load(): void
    {
        if (self::$loaded) {
            return;
        }

        self::$loaded = true;
        $configuredPath = getenv('ADMIN_ENV_FILE');
        
        $path = is_string($configuredPath) && $configuredPath !== ''
            ? $configuredPath
            : dirname(__DIR__) . DIRECTORY_SEPARATOR . '.env';

        if (is_file($path)) {
            $parsed = parse_ini_file($path, false, INI_SCANNER_RAW);
            if (is_array($parsed)) {
                foreach ($parsed as $key => $value) {
                    if (is_string($key) && is_scalar($value)) {
                        self::$values[$key] = trim((string) $value, " \t\n\r\0\x0B\"'");
                    }
                }
            }
        }
    }

    public static function get(string $key, ?string $default = null): ?string
    {
        self::load();
        $serverValue = getenv($key);
        if (is_string($serverValue) && $serverValue !== '') {
            return $serverValue;
        }
        return self::$values[$key] ?? $default;
    }

    public static function required(string $key): string
    {
        $value = self::get($key);
        if ($value === null || $value === '') {
            throw new RuntimeException("Missing required environment variable: {$key}");
        }
        return $value;
    }
}