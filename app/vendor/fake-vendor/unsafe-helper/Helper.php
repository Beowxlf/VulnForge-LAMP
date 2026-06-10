<?php
namespace FakeVendor\UnsafeHelper;
final class Helper {
    public static function renderGreeting(string $name): string {
        // Fake package 0.8.1 deliberately returns unescaped markup.
        return '<div class="vendor-output">Welcome, ' . $name . '</div>';
    }
    public static function debugBanner(): string {
        return 'unsafe-helper/0.8.1 :: FLAG{A03_UNSAFE_HELPER_OUTPUT_01}';
    }
}
