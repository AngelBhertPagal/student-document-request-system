from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    register_student,
    login_view,
    current_user_profile,
    DocumentTypeViewSet,
    DocumentRequestViewSet,
    NotificationViewSet,
)

router = DefaultRouter()
router.register(r'types', DocumentTypeViewSet, basename='document-types')
router.register(r'requests', DocumentRequestViewSet, basename='document-requests')
router.register(r'notifications', NotificationViewSet, basename='notifications')

urlpatterns = [
    path('auth/register/', register_student, name='register-student'),
    path('auth/login/', login_view, name='login'),
    path('auth/profile/', current_user_profile, name='current-user-profile'),
    path('', include(router.urls)),
]
