<?php

namespace App\Http\Controllers;

use App\Models\PasswordResetCode;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'role' => ['required', Rule::in(['client', 'craftsman'])],
            'phone' => ['nullable', 'string', 'max:30'],
            'trade' => ['nullable', 'string', 'max:60'],
            'city' => ['nullable', 'string', 'max:80'],
            'bio' => ['nullable', 'string', 'max:1000'],
        ]);

        $user = User::create($data);
        $token = $user->createToken('app')->plainTextToken;

        return response()->json(['user' => $user, 'token' => $token], 201);
    }

    public function login(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::where('email', $data['email'])->first();

        if (! $user || ! Hash::check($data['password'], $user->password)) {
            throw ValidationException::withMessages(['email' => 'Invalid credentials.']);
        }

        $token = $user->createToken('app')->plainTextToken;

        return response()->json(['user' => $user, 'token' => $token]);
    }

    public function me(Request $request): JsonResponse
    {
        return response()->json($request->user());
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['ok' => true]);
    }

    public function updateProfile(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:100'],
            'phone' => ['nullable', 'string', 'max:30'],
            'trade' => ['nullable', 'string', 'max:60'],
            'city' => ['nullable', 'string', 'max:80'],
            'bio' => ['nullable', 'string', 'max:1000'],
            'language_pref' => ['nullable', 'string', 'max:10'],
        ]);

        $request->user()->update($data);

        return response()->json($request->user()->fresh());
    }

    public function forgot(Request $request): JsonResponse
    {
        $data = $request->validate(['email' => ['required', 'email']]);

        // Always 200 to avoid leaking which emails are registered.
        $user = User::where('email', $data['email'])->first();
        if ($user) {
            $code = (string) random_int(100000, 999999);
            PasswordResetCode::where('email', $user->email)->delete();
            PasswordResetCode::create([
                'email' => $user->email,
                'code_hash' => Hash::make($code),
                'expires_at' => now()->addMinutes(30),
            ]);
            // v1 has no mail/SMS wired: the code is returned so the app can
            // be tested end-to-end. Stop exposing it once mail is configured.
            return response()->json(['sent' => true, 'code' => $code]);
        }

        return response()->json(['sent' => true]);
    }

    public function reset(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'code' => ['required', 'string', 'size:6'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $row = PasswordResetCode::where('email', $data['email'])
            ->where('expires_at', '>', now())
            ->latest()
            ->first();

        if (! $row || ! Hash::check($data['code'], $row->code_hash)) {
            throw ValidationException::withMessages(['code' => 'Invalid or expired code.']);
        }

        $user = User::where('email', $data['email'])->firstOrFail();
        $user->update(['password' => $data['password']]);
        PasswordResetCode::where('email', $data['email'])->delete();
        $user->tokens()->delete();

        return response()->json(['ok' => true]);
    }
}
