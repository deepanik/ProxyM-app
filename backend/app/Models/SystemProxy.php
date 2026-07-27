<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SystemProxy extends Model
{
    use HasFactory;

    protected $fillable = [
        'ip_address',
        'port',
        'username',
        'password',
        'protocol',
        'status',
    ];
}
