from django.contrib import admin
from django.urls import path, include
from django.shortcuts import redirect
from django.conf import settings
from django.conf.urls.static import static
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView, SpectacularRedocView

from documents.web_views import (
    staff_login_view,
    staff_logout_view,
    staff_dashboard_view,
    staff_request_detail_view,
    staff_request_action_view,
)

urlpatterns = [
    # Redirect root to staff dashboard or login
    path('', lambda request: redirect('staff-dashboard')),
    
    # Staff Web Portal
    path('staff/login/', staff_login_view, name='staff-login'),
    path('staff/logout/', staff_logout_view, name='staff-logout'),
    path('staff/dashboard/', staff_dashboard_view, name='staff-dashboard'),
    path('staff/requests/<int:pk>/', staff_request_detail_view, name='staff-request-detail'),
    path('staff/requests/<int:pk>/action/', staff_request_action_view, name='staff-request-action'),

    # Django Admin
    path('admin/', admin.site.urls),
    
    # REST APIs
    path('api/', include('documents.urls')),
    
    # OpenAPI 3 Schema & Swagger UI (Capstone requirement)
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
    path('api/redoc/', SpectacularRedocView.as_view(url_name='schema'), name='redoc'),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
