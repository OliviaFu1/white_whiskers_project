from django.contrib import admin
from .models import Pet, PetUser

admin.site.register(Pet)
admin.site.register(PetUser)