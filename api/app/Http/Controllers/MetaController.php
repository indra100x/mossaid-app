<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;

class MetaController extends Controller
{
    public function show(): JsonResponse
    {
        return response()->json([
            'trades' => config('marketplace.trades'),
            'cities' => config('marketplace.cities'),
            'cities_ar' => config('marketplace.cities_ar'),
        ]);
    }
}
