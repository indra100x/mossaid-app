<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('job_requests', function (Blueprint $table) {
            $table->string('cover_photo', 500)->nullable()->after('budget');
        });
    }

    public function down(): void
    {
        Schema::table('job_requests', function (Blueprint $table) {
            $table->dropColumn('cover_photo');
        });
    }
};
