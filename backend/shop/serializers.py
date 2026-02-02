# backend/shop/serializers.py
"""
Сериализаторы для NextStore E-commerce API
"""

from rest_framework import serializers
from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from .models import Category, Product, Profile, Order, OrderItem, Favorite


# ===========================================
# USER & AUTH SERIALIZERS
# ===========================================

class ProfileSerializer(serializers.ModelSerializer):
    """Сериализатор профиля пользователя"""
    
    class Meta:
        model = Profile
        fields = ['phone', 'avatar']
        read_only_fields = ['avatar']


class UserSerializer(serializers.ModelSerializer):
    """Сериализатор пользователя (для чтения)"""
    phone = serializers.CharField(source='profile.phone', read_only=True)
    avatar = serializers.ImageField(source='profile.avatar', read_only=True)
    
    class Meta:
        model = User
        fields = [
            'id', 
            'username', 
            'email', 
            'first_name', 
            'last_name', 
            'phone',
            'avatar',
            'date_joined'
        ]
        read_only_fields = ['id', 'date_joined']


class UserUpdateSerializer(serializers.ModelSerializer):
    """Сериализатор для обновления профиля пользователя"""
    phone = serializers.CharField(required=False)
    avatar = serializers.ImageField(required=False)
    
    class Meta:
        model = User
        fields = ['first_name', 'last_name', 'phone', 'avatar']
    
    def update(self, instance, validated_data):
        # Обновляем поля User
        instance.first_name = validated_data.get('first_name', instance.first_name)
        instance.last_name = validated_data.get('last_name', instance.last_name)
        instance.save()
        
        # Обновляем поля Profile
        phone = validated_data.get('phone')
        avatar = validated_data.get('avatar')
        
        if phone is not None:
            instance.profile.phone = phone
        if avatar is not None:
            instance.profile.avatar = avatar
        instance.profile.save()
        
        return instance


class RegisterSerializer(serializers.ModelSerializer):
    """Сериализатор регистрации"""
    phone = serializers.CharField(write_only=True, required=True)
    password = serializers.CharField(
        write_only=True, 
        required=True,
        style={'input_type': 'password'}
    )
    password_confirm = serializers.CharField(
        write_only=True, 
        required=False,
        style={'input_type': 'password'}
    )

    class Meta:
        model = User
        fields = [
            'username', 
            'password', 
            'password_confirm',
            'email', 
            'first_name', 
            'last_name', 
            'phone'
        ]
    
    def validate_username(self, value):
        """Проверка уникальности username"""
        if User.objects.filter(username__iexact=value).exists():
            raise serializers.ValidationError("Это имя пользователя уже занято")
        return value.lower()
    
    def validate_email(self, value):
        """Проверка уникальности email"""
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("Этот email уже зарегистрирован")
        return value.lower()
    
    def validate_phone(self, value):
        """Проверка уникальности телефона"""
        if Profile.objects.filter(phone=value).exists():
            raise serializers.ValidationError("Этот номер телефона уже зарегистрирован")
        return value
    
    def validate_password(self, value):
        """Валидация пароля"""
        try:
            validate_password(value)
        except ValidationError as e:
            raise serializers.ValidationError(list(e.messages))
        return value
    
    def validate(self, attrs):
        """Проверка совпадения паролей"""
        password_confirm = attrs.pop('password_confirm', None)
        if password_confirm and attrs['password'] != password_confirm:
            raise serializers.ValidationError({
                'password_confirm': 'Пароли не совпадают'
            })
        return attrs

    def create(self, validated_data):
        phone = validated_data.pop('phone')
        
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', ''),
            is_active=False  # Неактивен до подтверждения OTP
        )
        
        # Обновляем профиль (создан автоматически через signal)
        user.profile.phone = phone
        user.profile.save()
        
        return user


class ChangePasswordSerializer(serializers.Serializer):
    """Сериализатор смены пароля"""
    old_password = serializers.CharField(required=True)
    new_password = serializers.CharField(required=True)
    new_password_confirm = serializers.CharField(required=True)
    
    def validate_new_password(self, value):
        try:
            validate_password(value)
        except ValidationError as e:
            raise serializers.ValidationError(list(e.messages))
        return value
    
    def validate(self, attrs):
        if attrs['new_password'] != attrs['new_password_confirm']:
            raise serializers.ValidationError({
                'new_password_confirm': 'Пароли не совпадают'
            })
        return attrs


class ResetPasswordRequestSerializer(serializers.Serializer):
    """Сериализатор запроса сброса пароля"""
    email = serializers.EmailField(required=True)
    
    def validate_email(self, value):
        if not User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("Пользователь с таким email не найден")
        return value.lower()


class ResetPasswordConfirmSerializer(serializers.Serializer):
    """Сериализатор подтверждения сброса пароля"""
    email = serializers.EmailField(required=True)
    code = serializers.CharField(required=True, max_length=6)
    new_password = serializers.CharField(required=True)
    
    def validate_new_password(self, value):
        try:
            validate_password(value)
        except ValidationError as e:
            raise serializers.ValidationError(list(e.messages))
        return value


# ===========================================
# CATALOG SERIALIZERS
# ===========================================

class CategorySerializer(serializers.ModelSerializer):
    """Сериализатор категорий"""
    products_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Category
        fields = ['id', 'name', 'slug', 'image', 'products_count']
    
    def get_products_count(self, obj):
        """Количество активных товаров в категории"""
        return obj.products.filter(is_active=True).count()


class ProductListSerializer(serializers.ModelSerializer):
    """Сериализатор списка товаров (краткий)"""
    category_name = serializers.CharField(source='category.name', read_only=True)
    category_slug = serializers.CharField(source='category.slug', read_only=True)
    in_stock = serializers.BooleanField(read_only=True)
    is_favorite = serializers.SerializerMethodField()
    
    class Meta:
        model = Product
        fields = [
            'id', 
            'name', 
            'category',
            'category_name',
            'category_slug',
            'price', 
            'stock',
            'in_stock',
            'image', 
            'is_favorite',
            'created'
        ]
    
    def get_is_favorite(self, obj):
        """Проверка, добавлен ли товар в избранное текущим пользователем"""
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return Favorite.objects.filter(user=request.user, product=obj).exists()
        return False


class ProductDetailSerializer(serializers.ModelSerializer):
    """Сериализатор детальной информации о товаре"""
    category_name = serializers.CharField(source='category.name', read_only=True)
    category_slug = serializers.CharField(source='category.slug', read_only=True)
    in_stock = serializers.BooleanField(read_only=True)
    is_favorite = serializers.SerializerMethodField()
    
    class Meta:
        model = Product
        fields = [
            'id', 
            'name',
            'category',
            'category_name',
            'category_slug',
            'description',
            'price', 
            'stock',
            'in_stock',
            'image',
            'is_favorite',
            'created',
            'updated'
        ]
    
    def get_is_favorite(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return Favorite.objects.filter(user=request.user, product=obj).exists()
        return False


# ===========================================
# ORDER SERIALIZERS
# ===========================================

class OrderItemSerializer(serializers.ModelSerializer):
    """Сериализатор позиции заказа"""
    product_id = serializers.UUIDField(source='product.id', read_only=True)
    product_image = serializers.ImageField(source='product.image', read_only=True)
    total = serializers.SerializerMethodField()
    
    class Meta:
        model = OrderItem
        fields = [
            'id',
            'product_id',
            'product_name', 
            'product_image',
            'price', 
            'quantity',
            'total'
        ]
    
    def get_total(self, obj):
        return str(obj.get_cost())


class OrderItemCreateSerializer(serializers.Serializer):
    """Сериализатор для создания позиции заказа"""
    product_id = serializers.UUIDField(required=True)
    quantity = serializers.IntegerField(min_value=1, default=1)
    
    def validate_product_id(self, value):
        try:
            product = Product.objects.get(id=value, is_active=True)
        except Product.DoesNotExist:
            raise serializers.ValidationError("Товар не найден")
        return value


class OrderListSerializer(serializers.ModelSerializer):
    """Сериализатор списка заказов (краткий)"""
    items_count = serializers.IntegerField(source='items.count', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    
    class Meta:
        model = Order
        fields = [
            'id',
            'order_number',
            'status',
            'status_display',
            'total_amount',
            'items_count',
            'created_at'
        ]


class OrderDetailSerializer(serializers.ModelSerializer):
    """Сериализатор детальной информации о заказе"""
    items = OrderItemSerializer(many=True, read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    
    class Meta:
        model = Order
        fields = [
            'id',
            'order_number',
            'first_name',
            'last_name',
            'phone',
            'email',
            'address',
            'status',
            'status_display',
            'total_amount',
            'note',
            'items',
            'created_at',
            'updated_at'
        ]


class OrderCreateSerializer(serializers.Serializer):
    """Сериализатор создания заказа"""
    first_name = serializers.CharField(max_length=100)
    last_name = serializers.CharField(max_length=100)
    phone = serializers.CharField(max_length=20)
    email = serializers.EmailField(required=False, allow_blank=True)
    address = serializers.CharField()
    note = serializers.CharField(required=False, allow_blank=True)
    items = OrderItemCreateSerializer(many=True)
    
    def validate_items(self, value):
        if not value:
            raise serializers.ValidationError("Корзина пуста")
        
        # Проверяем наличие товаров на складе
        errors = []
        for item in value:
            try:
                product = Product.objects.get(id=item['product_id'], is_active=True)
                if product.stock < item['quantity']:
                    errors.append(f"Недостаточно товара '{product.name}' на складе")
            except Product.DoesNotExist:
                errors.append(f"Товар не найден")
        
        if errors:
            raise serializers.ValidationError(errors)
        
        return value
    
    def create(self, validated_data):
        items_data = validated_data.pop('items')
        user = self.context.get('request').user
        
        # Вычисляем общую сумму
        total_amount = 0
        products_data = []
        
        for item_data in items_data:
            product = Product.objects.get(id=item_data['product_id'])
            quantity = item_data['quantity']
            total_amount += product.price * quantity
            products_data.append({
                'product': product,
                'quantity': quantity
            })
        
        # Создаем заказ
        order = Order.objects.create(
            user=user if user.is_authenticated else None,
            first_name=validated_data['first_name'],
            last_name=validated_data['last_name'],
            phone=validated_data['phone'],
            email=validated_data.get('email', ''),
            address=validated_data['address'],
            note=validated_data.get('note', ''),
            total_amount=total_amount
        )
        
        # Создаем позиции заказа и уменьшаем остаток
        for data in products_data:
            product = data['product']
            quantity = data['quantity']
            
            OrderItem.objects.create(
                order=order,
                product=product,
                product_name=product.name,
                price=product.price,
                quantity=quantity
            )
            
            # Уменьшаем остаток на складе
            product.stock -= quantity
            product.save()
        
        return order


# ===========================================
# FAVORITE SERIALIZERS
# ===========================================

class FavoriteSerializer(serializers.ModelSerializer):
    """Сериализатор избранного"""
    product = ProductListSerializer(read_only=True)
    
    class Meta:
        model = Favorite
        fields = ['id', 'product', 'created_at']


class FavoriteCreateSerializer(serializers.Serializer):
    """Сериализатор добавления в избранное"""
    product_id = serializers.UUIDField(required=True)
    
    def validate_product_id(self, value):
        try:
            Product.objects.get(id=value, is_active=True)
        except Product.DoesNotExist:
            raise serializers.ValidationError("Товар не найден")
        return value
    
    def create(self, validated_data):
        user = self.context['request'].user
        product = Product.objects.get(id=validated_data['product_id'])
        
        favorite, created = Favorite.objects.get_or_create(
            user=user,
            product=product
        )
        
        return favorite