# backend/shop/views.py
"""
API Views для NextStore E-commerce
"""

import random
from datetime import timedelta

from django.core.mail import send_mail
from django.conf import settings
from django.contrib.auth.models import User
from django.utils import timezone
from django.db.models import Q

from rest_framework import generics, permissions, status, filters
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.decorators import api_view, permission_classes
from rest_framework_simplejwt.tokens import RefreshToken

from .models import Category, Product, Profile, Order, OrderItem, Favorite
from .serializers import (
    # Auth
    UserSerializer,
    UserUpdateSerializer,
    RegisterSerializer,
    ChangePasswordSerializer,
    ResetPasswordRequestSerializer,
    ResetPasswordConfirmSerializer,
    # Catalog
    CategorySerializer,
    ProductListSerializer,
    ProductDetailSerializer,
    # Orders
    OrderListSerializer,
    OrderDetailSerializer,
    OrderCreateSerializer,
    # Favorites
    FavoriteSerializer,
    FavoriteCreateSerializer,
)


# ===========================================
# HELPER FUNCTIONS
# ===========================================

def get_tokens_for_user(user):
    """Генерация JWT токенов для пользователя"""
    refresh = RefreshToken.for_user(user)
    return {
        'refresh': str(refresh),
        'access': str(refresh.access_token)
    }


def generate_otp():
    """Генерация 6-значного OTP кода"""
    return str(random.randint(100000, 999999))


def send_otp_email(email, otp, subject="Код подтверждения NEXTSTORE"):
    """Отправка OTP кода на email"""
    message = f"""
Здравствуйте!

Ваш код подтверждения: {otp}

Код действителен в течение 10 минут.

Если вы не запрашивали этот код, просто проигнорируйте это письмо.

С уважением,
Команда NEXTSTORE
    """
    try:
        send_mail(
            subject,
            message,
            settings.DEFAULT_FROM_EMAIL,
            [email],
            fail_silently=False,
        )
        return True
    except Exception as e:
        print(f"Email error: {e}")
        return False


# ===========================================
# LIVE VALIDATION VIEWS (Проверка уникальности)
# ===========================================

class CheckUsernameView(APIView):
    """Проверка доступности username"""
    permission_classes = [permissions.AllowAny]
    
    def get(self, request):
        username = request.query_params.get('username', '').strip().lower()
        if not username:
            return Response({"error": "Username required"}, status=400)
        exists = User.objects.filter(username__iexact=username).exists()
        return Response({"exists": exists})


class CheckEmailView(APIView):
    """Проверка доступности email"""
    permission_classes = [permissions.AllowAny]
    
    def get(self, request):
        email = request.query_params.get('email', '').strip().lower()
        if not email:
            return Response({"error": "Email required"}, status=400)
        exists = User.objects.filter(email__iexact=email).exists()
        return Response({"exists": exists})


class CheckPhoneView(APIView):
    """Проверка доступности телефона"""
    permission_classes = [permissions.AllowAny]
    
    def get(self, request):
        phone = request.query_params.get('phone', '').strip()
        if not phone:
            return Response({"error": "Phone required"}, status=400)
        exists = Profile.objects.filter(phone=phone).exists()
        return Response({"exists": exists})


# ===========================================
# AUTHENTICATION VIEWS
# ===========================================

class RegisterView(APIView):
    """
    Регистрация пользователя (Шаг 1)
    Создает неактивного пользователя и отправляет OTP на email
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        data = request.data.copy()
        
        # Нормализация данных
        if 'email' in data:
            data['email'] = data['email'].lower().strip()
        if 'username' in data:
            data['username'] = data['username'].lower().strip()
        if 'phone' in data:
            data['phone'] = data['phone'].strip()

        serializer = RegisterSerializer(data=data)
        
        if not serializer.is_valid():
            return Response({
                "error": "Ошибка валидации",
                "details": serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Создаем пользователя
        user = serializer.save()
        
        # Генерируем и сохраняем OTP
        otp = generate_otp()
        user.profile.otp_code = otp
        user.profile.otp_created_at = timezone.now()
        user.profile.save()

        # Отправляем email
        if send_otp_email(user.email, otp):
            return Response({
                "status": "code_sent",
                "message": "Код подтверждения отправлен на ваш email"
            }, status=status.HTTP_201_CREATED)
        else:
            # Откатываем создание пользователя если email не отправился
            user.delete()
            return Response({
                "error": "Ошибка отправки email. Проверьте настройки SMTP."
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class VerifyOTPView(APIView):
    """
    Подтверждение OTP кода (Шаг 2)
    Активирует пользователя и возвращает JWT токены
    """
    permission_classes = [permissions.AllowAny]
    
    def post(self, request):
        email = request.data.get('email', '').strip().lower()
        code = str(request.data.get('code', '')).strip()
        
        if not email or not code:
            return Response({
                "error": "Email и код обязательны"
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            user = User.objects.get(email__iexact=email)
        except User.DoesNotExist:
            return Response({
                "error": "Пользователь не найден"
            }, status=status.HTTP_404_NOT_FOUND)
        
        # Проверяем OTP
        if user.profile.otp_code != code:
            return Response({
                "error": "Неверный код"
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Проверяем срок действия OTP (10 минут)
        if user.profile.otp_created_at:
            otp_age = timezone.now() - user.profile.otp_created_at
            if otp_age > timedelta(minutes=10):
                return Response({
                    "error": "Код истек. Запросите новый."
                }, status=status.HTTP_400_BAD_REQUEST)
        
        # Активируем пользователя
        user.is_active = True
        user.save()
        
        # Очищаем OTP
        user.profile.otp_code = None
        user.profile.otp_created_at = None
        user.profile.save()
        
        return Response({
            "status": "success",
            "message": "Регистрация завершена",
            "tokens": get_tokens_for_user(user),
            "user": UserSerializer(user).data
        })


class ResendOTPView(APIView):
    """Повторная отправка OTP кода"""
    permission_classes = [permissions.AllowAny]
    
    def post(self, request):
        email = request.data.get('email', '').strip().lower()
        
        if not email:
            return Response({
                "error": "Email обязателен"
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            user = User.objects.get(email__iexact=email)
        except User.DoesNotExist:
            return Response({
                "error": "Пользователь не найден"
            }, status=status.HTTP_404_NOT_FOUND)
        
        if user.is_active:
            return Response({
                "error": "Аккаунт уже активирован"
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Генерируем новый OTP
        otp = generate_otp()
        user.profile.otp_code = otp
        user.profile.otp_created_at = timezone.now()
        user.profile.save()
        
        if send_otp_email(user.email, otp):
            return Response({
                "status": "code_sent",
                "message": "Новый код отправлен"
            })
        else:
            return Response({
                "error": "Ошибка отправки email"
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class ResetPasswordRequestView(APIView):
    """
    Запрос сброса пароля (Шаг 1)
    Отправляет OTP на email
    """
    permission_classes = [permissions.AllowAny]
    
    def post(self, request):
        serializer = ResetPasswordRequestSerializer(data=request.data)
        
        if not serializer.is_valid():
            return Response({
                "error": "Ошибка валидации",
                "details": serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)
        
        email = serializer.validated_data['email']
        user = User.objects.get(email__iexact=email)
        
        # Генерируем OTP
        otp = generate_otp()
        user.profile.otp_code = otp
        user.profile.otp_created_at = timezone.now()
        user.profile.save()
        
        if send_otp_email(user.email, otp, subject="Сброс пароля NEXTSTORE"):
            return Response({
                "status": "code_sent",
                "message": "Код для сброса пароля отправлен на email"
            })
        else:
            return Response({
                "error": "Ошибка отправки email"
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class ResetPasswordConfirmView(APIView):
    """
    Подтверждение сброса пароля (Шаг 2)
    Проверяет OTP и устанавливает новый пароль
    """
    permission_classes = [permissions.AllowAny]
    
    def post(self, request):
        serializer = ResetPasswordConfirmSerializer(data=request.data)
        
        if not serializer.is_valid():
            return Response({
                "error": "Ошибка валидации",
                "details": serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)
        
        email = serializer.validated_data['email']
        code = serializer.validated_data['code']
        new_password = serializer.validated_data['new_password']
        
        try:
            user = User.objects.get(email__iexact=email)
        except User.DoesNotExist:
            return Response({
                "error": "Пользователь не найден"
            }, status=status.HTTP_404_NOT_FOUND)
        
        # Проверяем OTP
        if user.profile.otp_code != code:
            return Response({
                "error": "Неверный код"
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Проверяем срок действия
        if user.profile.otp_created_at:
            otp_age = timezone.now() - user.profile.otp_created_at
            if otp_age > timedelta(minutes=10):
                return Response({
                    "error": "Код истек. Запросите новый."
                }, status=status.HTTP_400_BAD_REQUEST)
        
        # Устанавливаем новый пароль
        user.set_password(new_password)
        user.save()
        
        # Очищаем OTP
        user.profile.otp_code = None
        user.profile.otp_created_at = None
        user.profile.save()
        
        return Response({
            "status": "success",
            "message": "Пароль успешно изменен",
            "tokens": get_tokens_for_user(user)
        })


# ===========================================
# PROFILE VIEWS
# ===========================================

class ProfileView(APIView):
    """Получение и обновление профиля текущего пользователя"""
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        """Получить профиль"""
        serializer = UserSerializer(request.user)
        return Response(serializer.data)
    
    def put(self, request):
        """Обновить профиль"""
        serializer = UserUpdateSerializer(
            request.user,
            data=request.data,
            partial=True
        )
        
        if serializer.is_valid():
            serializer.save()
            return Response({
                "status": "success",
                "message": "Профиль обновлен",
                "user": UserSerializer(request.user).data
            })
        
        return Response({
            "error": "Ошибка валидации",
            "details": serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)
    
    def patch(self, request):
        """Частичное обновление профиля"""
        return self.put(request)


class ChangePasswordView(APIView):
    """Смена пароля авторизованного пользователя"""
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        serializer = ChangePasswordSerializer(data=request.data)
        
        if not serializer.is_valid():
            return Response({
                "error": "Ошибка валидации",
                "details": serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)
        
        user = request.user
        
        # Проверяем старый пароль
        if not user.check_password(serializer.validated_data['old_password']):
            return Response({
                "error": "Неверный текущий пароль"
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Устанавливаем новый пароль
        user.set_password(serializer.validated_data['new_password'])
        user.save()
        
        return Response({
            "status": "success",
            "message": "Пароль успешно изменен",
            "tokens": get_tokens_for_user(user)  # Новые токены
        })


# ===========================================
# CATALOG VIEWS
# ===========================================

class CategoryListView(generics.ListAPIView):
    """Список категорий"""
    serializer_class = CategorySerializer
    permission_classes = [permissions.AllowAny]
    
    def get_queryset(self):
        return Category.objects.filter(is_active=True)


class ProductListView(generics.ListAPIView):
    """
    Список товаров с фильтрацией, поиском и сортировкой
    
    Query параметры:
    - category: slug категории
    - search: поисковый запрос
    - ordering: сортировка (price, -price, created, -created, name)
    - min_price: минимальная цена
    - max_price: максимальная цена
    - in_stock: только в наличии (true/false)
    """
    serializer_class = ProductListSerializer
    permission_classes = [permissions.AllowAny]
    
    def get_queryset(self):
        queryset = Product.objects.filter(is_active=True)
        params = self.request.query_params
        
        # Фильтр по категории
        category_slug = params.get('category')
        if category_slug:
            queryset = queryset.filter(category__slug=category_slug)
        
        # Поиск по названию и описанию
        search = params.get('search')
        if search:
            queryset = queryset.filter(
                Q(name__icontains=search) | 
                Q(description__icontains=search)
            )
        
        # Фильтр по цене
        min_price = params.get('min_price')
        max_price = params.get('max_price')
        if min_price:
            queryset = queryset.filter(price__gte=min_price)
        if max_price:
            queryset = queryset.filter(price__lte=max_price)
        
        # Только в наличии
        in_stock = params.get('in_stock')
        if in_stock and in_stock.lower() == 'true':
            queryset = queryset.filter(stock__gt=0)
        
        # Сортировка
        ordering = params.get('ordering', '-created')
        allowed_ordering = ['price', '-price', 'created', '-created', 'name', '-name']
        if ordering in allowed_ordering:
            queryset = queryset.order_by(ordering)
        
        return queryset
    
    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context


class ProductDetailView(generics.RetrieveAPIView):
    """Детальная информация о товаре"""
    serializer_class = ProductDetailSerializer
    permission_classes = [permissions.AllowAny]
    lookup_field = 'id'
    
    def get_queryset(self):
        return Product.objects.filter(is_active=True)
    
    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context


# ===========================================
# ORDER VIEWS
# ===========================================

class OrderListView(generics.ListAPIView):
    """Список заказов текущего пользователя"""
    serializer_class = OrderListSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        return Order.objects.filter(user=self.request.user)


class OrderDetailView(generics.RetrieveAPIView):
    """Детали заказа"""
    serializer_class = OrderDetailSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'id'
    
    def get_queryset(self):
        return Order.objects.filter(user=self.request.user)


class OrderCreateView(APIView):
    """Создание нового заказа"""
    permission_classes = [permissions.AllowAny]  # Гостевой заказ разрешен
    
    def post(self, request):
        serializer = OrderCreateSerializer(
            data=request.data,
            context={'request': request}
        )
        
        if not serializer.is_valid():
            return Response({
                "error": "Ошибка валидации",
                "details": serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)
        
        order = serializer.save()
        
        # Отправляем email с подтверждением (опционально)
        if order.email:
            try:
                send_mail(
                    f'Заказ #{order.order_number} принят',
                    f'Спасибо за заказ!\n\n'
                    f'Номер заказа: {order.order_number}\n'
                    f'Сумма: {order.total_amount} TMT\n\n'
                    f'Мы свяжемся с вами в ближайшее время.',
                    settings.DEFAULT_FROM_EMAIL,
                    [order.email],
                    fail_silently=True,
                )
            except Exception:
                pass  # Не блокируем заказ если email не отправился
        
        return Response({
            "status": "success",
            "message": "Заказ успешно создан",
            "order": OrderDetailSerializer(order).data
        }, status=status.HTTP_201_CREATED)


class OrderCancelView(APIView):
    """Отмена заказа"""
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request, id):
        try:
            order = Order.objects.get(id=id, user=request.user)
        except Order.DoesNotExist:
            return Response({
                "error": "Заказ не найден"
            }, status=status.HTTP_404_NOT_FOUND)
        
        # Можно отменить только заказы в статусе pending или confirmed
        if order.status not in ['pending', 'confirmed']:
            return Response({
                "error": "Этот заказ нельзя отменить"
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Возвращаем товары на склад
        for item in order.items.all():
            if item.product:
                item.product.stock += item.quantity
                item.product.save()
        
        order.status = Order.OrderStatus.CANCELLED
        order.save()
        
        return Response({
            "status": "success",
            "message": "Заказ отменен"
        })


# ===========================================
# FAVORITE VIEWS
# ===========================================

class FavoriteListView(generics.ListAPIView):
    """Список избранных товаров"""
    serializer_class = FavoriteSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        return Favorite.objects.filter(user=self.request.user)


class FavoriteToggleView(APIView):
    """Добавить/удалить товар из избранного"""
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        """Добавить в избранное"""
        serializer = FavoriteCreateSerializer(
            data=request.data,
            context={'request': request}
        )
        
        if not serializer.is_valid():
            return Response({
                "error": "Ошибка валидации",
                "details": serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)
        
        product_id = serializer.validated_data['product_id']
        product = Product.objects.get(id=product_id)
        
        favorite, created = Favorite.objects.get_or_create(
            user=request.user,
            product=product
        )
        
        if created:
            return Response({
                "status": "added",
                "message": "Товар добавлен в избранное"
            }, status=status.HTTP_201_CREATED)
        else:
            return Response({
                "status": "exists",
                "message": "Товар уже в избранном"
            })
    
    def delete(self, request):
        """Удалить из избранного"""
        product_id = request.data.get('product_id')
        
        if not product_id:
            return Response({
                "error": "product_id обязателен"
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            favorite = Favorite.objects.get(
                user=request.user,
                product_id=product_id
            )
            favorite.delete()
            return Response({
                "status": "removed",
                "message": "Товар удален из избранного"
            })
        except Favorite.DoesNotExist:
            return Response({
                "error": "Товар не найден в избранном"
            }, status=status.HTTP_404_NOT_FOUND)


class FavoriteDeleteView(APIView):
    """Удалить конкретный товар из избранного по ID товара"""
    permission_classes = [permissions.IsAuthenticated]
    
    def delete(self, request, product_id):
        try:
            favorite = Favorite.objects.get(
                user=request.user,
                product_id=product_id
            )
            favorite.delete()
            return Response({
                "status": "removed",
                "message": "Товар удален из избранного"
            })
        except Favorite.DoesNotExist:
            return Response({
                "error": "Товар не найден в избранном"
            }, status=status.HTTP_404_NOT_FOUND)