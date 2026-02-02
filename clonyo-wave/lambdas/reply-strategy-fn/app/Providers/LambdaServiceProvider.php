<?php

declare(strict_types=1);

namespace App\Providers;

use Illuminate\Support\ServiceProvider;

class LambdaServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        // Configure storage path for Lambda environment
        if (isset($_ENV['LAMBDA_TASK_ROOT'])) {
            $this->app->useStoragePath('/tmp/storage');
        }
    }

    public function boot(): void
    {
        //
    }
}
