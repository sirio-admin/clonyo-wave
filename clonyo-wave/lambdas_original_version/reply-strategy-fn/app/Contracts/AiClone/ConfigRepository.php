<?php

namespace App\Contracts\AiClone;

use App\Data\AiClone\Config\ConfigData;

interface ConfigRepository
{
    public function get(string $key_value): ?ConfigData;

    public function put(ConfigData $config): bool;
}
