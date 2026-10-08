<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('role', 20)->default('client')->after('password');
            $table->string('phone', 30)->nullable()->after('role');
            $table->string('trade', 60)->nullable()->after('phone');
            $table->string('city', 80)->nullable()->after('trade');
            $table->text('bio')->nullable()->after('city');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['role', 'phone', 'trade', 'city', 'bio']);
        });
    }
};
