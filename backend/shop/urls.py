# backend/shop/urls.py
"""
URL маршруты для NextStore API
"""

from django.urls import path
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)

from .views import (
    # Live Validation
    CheckUsernameView,
    CheckEmailView,
    CheckPhoneView,
    
    # Authentication
    RegisterView,
    VerifyOTPView,
    ResendOTPView,
    ResetPasswordRequestView,
    ResetPasswordConfirmView,
    
    # Profile
    ProfileView,
    ChangePasswordView,
    
    # Catalog
    CategoryListView,
    ProductListView,
    ProductDetailView,
    
    # Orders
    OrderListView,
    OrderDetailView,
    OrderCreateView,
    OrderCancelView,
    
    # Favorites
    FavoriteListView,
    FavoriteToggleView,
    FavoriteDeleteView,
)

urlpatterns = [
    # ===========================================
    # AUTHENTICATION
    # ===========================================
    
    # JWT токены
    path('login/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    
    # Регистрация
    path('register/', RegisterView.as_view(), name='register'),
    path('verify-otp/', VerifyOTPView.as_view(), name='verify_otp'),
    path('resend-otp/', ResendOTPView.as_view(), name='resend_otp'),
    
    # Сброс пароля
    path('reset-password/', ResetPasswordRequestView.as_view(), name='reset_password'),
    path('reset-password/confirm/', ResetPasswordConfirmView.as_view(), name='reset_password_confirm'),
    
    # Live validation (проверка уникальности)
    path('check-username/', CheckUsernameView.as_view(), name='check_username'),
    path('check-email/', CheckEmailView.as_view(), name='check_email'),
    path('check-phone/', CheckPhoneView.as_view(), name='check_phone'),
    
    # ===========================================
    # PROFILE
    # ===========================================
    path('profile/', ProfileView.as_view(), name='profile'),
    path('profile/change-password/', ChangePasswordView.as_view(), name='change_password'),
    
    # ===========================================
    # CATALOG
    # ===========================================
    path('categories/', CategoryListView.as_view(), name='category_list'),
    path('products/', ProductListView.as_view(), name='product_list'),
    path('products/<uuid:id>/', ProductDetailView.as_view(), name='product_detail'),
    
    # ===========================================
    # ORDERS
    # ===========================================
    path('orders/', OrderListView.as_view(), name='order_list'),
    path('orders/create/', OrderCreateView.as_view(), name='order_create'),
    path('orders/<int:id>/', OrderDetailView.as_view(), name='order_detail'),
    path('orders/<int:id>/cancel/', OrderCancelView.as_view(), name='order_cancel'),
    
    # ===========================================
    # FAVORITES
    # ===========================================
    path('favorites/', FavoriteListView.as_view(), name='favorite_list'),
    path('favorites/toggle/', FavoriteToggleView.as_view(), name='favorite_toggle'),
    path('favorites/<uuid:product_id>/', FavoriteDeleteView.as_view(), name='favorite_delete'),
]