<?php

namespace Database\Seeders;

use App\Models\User;
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
        User::updateOrCreate(
            ['email' => 'admin@proxym.com'],
            [
                'name' => 'Admin User',
                'password' => bcrypt('adminpassword123'),
                'is_admin' => true,
            ]
        );

        // Test Normal User
        User::updateOrCreate(
            ['email' => 'test@example.com'],
            [
                'name' => 'Test User',
                'password' => bcrypt('userpassword123'),
                'is_admin' => false,
            ]
        );
    }
}
