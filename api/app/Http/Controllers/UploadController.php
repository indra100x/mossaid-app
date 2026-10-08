<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class UploadController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'photo' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
            'folder' => ['nullable', 'string', 'in:posts,jobs,avatars'],
        ]);

        $folder = $data['folder'] ?? 'posts';
        $path = $request->file('photo')->store($folder, 'public');

        return response()->json([
            'url' => url(Storage::url($path)),
            'path' => $path,
        ], 201);
    }
}
