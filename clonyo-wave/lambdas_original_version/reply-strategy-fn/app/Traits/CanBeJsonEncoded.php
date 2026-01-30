<?php

namespace App\Traits;

trait CanBeJsonEncoded
{
    public function jsonEncode(): string
    {
        return json_encode($this);
    }

    public function toArray(): array
    {
        return json_decode($this->jsonEncode(), true);
    }
}
