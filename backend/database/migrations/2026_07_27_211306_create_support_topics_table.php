<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('support_topics', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->timestamps();
        });

        // Insert initial default topics
        DB::table('support_topics')->insert([
            ['name' => 'Proxy Connection Failing', 'created_at' => now(), 'updated_at' => now()],
            ['name' => 'Slow Proxy Speed / High Latency', 'created_at' => now(), 'updated_at' => now()],
            ['name' => 'IP Whitelist & Authentication Request', 'created_at' => now(), 'updated_at' => now()],
            ['name' => 'Extension & App Integration Bug', 'created_at' => now(), 'updated_at' => now()],
        ]);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('support_topics');
    }
};
