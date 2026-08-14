<?php

namespace Database\Seeders;

use App\Models\User;
use App\Models\Proxy;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // Default Admin User
        $admin = User::updateOrCreate(
            ['email' => 'admin@proxym.com'],
            [
                'name' => 'Admin User',
                'password' => bcrypt('adminpassword123'),
                'is_admin' => true,
            ]
        );

        // Test Normal User
        $testUser = User::updateOrCreate(
            ['email' => 'test@example.com'],
            [
                'name' => 'Test User',
                'password' => bcrypt('userpassword123'),
                'is_admin' => false,
            ]
        );

        // Real Webshare proxies
        $webshareProxies = [
            ['ip_address' => '31.56.127.193', 'port' => 7684, 'username' => 'ldwjblcl-US', 'password' => 'a8iosw2n05qd'],
            ['ip_address' => '198.23.243.226', 'port' => 6361, 'username' => 'ldwjblcl-US', 'password' => 'a8iosw2n05qd'],
            ['ip_address' => '38.154.185.97', 'port' => 6370, 'username' => 'ldwjblcl-US', 'password' => 'a8iosw2n05qd'],
            ['ip_address' => '191.96.254.138', 'port' => 6185, 'username' => 'ldwjblcl-US', 'password' => 'a8iosw2n05qd'],
        ];

        foreach ([$admin, $testUser] as $user) {
            foreach ($webshareProxies as $p) {
                $user->proxies()->updateOrCreate(
                    ['ip_address' => $p['ip_address'], 'port' => $p['port']],
                    [
                        'username' => $p['username'],
                        'password' => $p['password'],
                        'status' => 'ok',
                    ]
                );
            }
        }
    }
}
