<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\JobController;
use App\Http\Controllers\MessageController;
use App\Http\Controllers\MetaController;
use App\Http\Controllers\NotificationController;
use App\Http\Controllers\PostController;
use App\Http\Controllers\ReviewController;
use App\Http\Controllers\UploadController;
use Illuminate\Support\Facades\Route;

Route::get('/health', fn () => response()->json(['ok' => true, 'service' => 'mossaid-simple-api']));

Route::get('/meta', [MetaController::class, 'show']);
Route::get('/craftsmen/{user}/reviews', [ReviewController::class, 'forCraftsman']);

Route::post('/auth/register', [AuthController::class, 'register']);
Route::post('/auth/login', [AuthController::class, 'login']);
Route::post('/auth/forgot', [AuthController::class, 'forgot']);
Route::post('/auth/reset', [AuthController::class, 'reset']);

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/auth/me', [AuthController::class, 'me']);
    Route::patch('/auth/profile', [AuthController::class, 'updateProfile']);
    Route::post('/auth/logout', [AuthController::class, 'logout']);

    Route::post('/uploads', [UploadController::class, 'store']);

    Route::get('/notifications', [NotificationController::class, 'index']);
    Route::post('/notifications/read', [NotificationController::class, 'read']);

    Route::get('/posts', [PostController::class, 'index']);
    Route::post('/posts', [PostController::class, 'store']);
    Route::get('/posts/{post}', [PostController::class, 'show']);
    Route::patch('/posts/{post}', [PostController::class, 'update']);
    Route::delete('/posts/{post}', [PostController::class, 'destroy']);
    Route::post('/posts/{post}/like', [PostController::class, 'toggleLike']);
    Route::get('/posts/{post}/comments', [PostController::class, 'comments']);
    Route::post('/posts/{post}/comments', [PostController::class, 'addComment']);

    Route::get('/jobs', [JobController::class, 'index']);
    Route::post('/jobs', [JobController::class, 'store']);
    Route::get('/jobs/{job}', [JobController::class, 'show']);
    Route::post('/jobs/{job}/accept', [JobController::class, 'accept']);
    Route::post('/jobs/{job}/complete', [JobController::class, 'complete']);
    Route::post('/jobs/{job}/cancel', [JobController::class, 'cancel']);
    Route::post('/jobs/{job}/reviews', [ReviewController::class, 'store']);

    Route::get('/jobs/{job}/messages', [MessageController::class, 'index']);
    Route::post('/jobs/{job}/messages', [MessageController::class, 'store']);
});
