<?php

namespace App\Console\Commands\AiClone\Config;

use App\Contracts\AiClone\ConfigRepository;
use App\Data\AiClone\Config\ConfigData;
use Illuminate\Console\Command;

class CreateCommand extends Command
{
    public function __construct(
        protected ConfigRepository $ai_clone_config
    ) {
        parent::__construct();
    }

    protected $signature = 'ai-clone:config:create {wa_phone_number_arn} {config_name} {--f|force}';

    protected function getWaPhoneNumberArn(): string
    {
        return $this->argument('wa_phone_number_arn');
    }

    protected function getConfigName(): string
    {
        return $this->argument('config_name');
    }

    protected function shouldOverride(): bool
    {
        if ($this->option('force')) {
            return true;
        }

        $current_item = $this->ai_clone_config->get($this->getWaPhoneNumberArn());
        if (empty($current_item)) {
            return true;
        }

        return $this->confirm("A config for {$this->getWaPhoneNumberArn()} already esists. Do you want to overwrite it?");
    }

    public function handle()
    {
        if (! $this->shouldOverride()) {
            $this->warn('Config creation skipped. Use the `--force` option to override the existing config.');

            return 1;
        }

        $config = ConfigData::newFrom(
            $this->getWaPhoneNumberArn(),
            $this->getConfigName()
        );

        $result = $this->ai_clone_config->put($config);

        if ($result) {
            $this->info('Config created.');
        } else {
            $this->error('Config creation failed.');
        }
    }
}
