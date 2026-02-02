# backend/shop/models.py
"""
Модели для NextStore E-commerce приложения
"""

import uuid
from django.db import models
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.core.validators import MinValueValidator
from decimal import Decimal


class Category(models.Model):
    """Категории товаров"""
    name = models.CharField(max_length=200, verbose_name="Название категории")
    slug = models.SlugField(unique=True)
    image = models.ImageField(
        upload_to='categories/', 
        blank=True, 
        null=True,
        verbose_name="Изображение категории"
    )
    is_active = models.BooleanField(default=True, verbose_name="Активна")
    
    class Meta:
        verbose_name = "Категория"
        verbose_name_plural = "Категории"
        ordering = ['name']

    def __str__(self):
        return self.name


class Product(models.Model):
    """Товары"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    category = models.ForeignKey(
        Category, 
        related_name='products', 
        on_delete=models.CASCADE, 
        verbose_name="Категория"
    )
    name = models.CharField(max_length=255, verbose_name="Наименование товара")
    description = models.TextField(blank=True, verbose_name="Описание")
    price = models.DecimalField(
        max_digits=10, 
        decimal_places=2, 
        validators=[MinValueValidator(Decimal('0.01'))],
        verbose_name="Цена"
    )
    stock = models.PositiveIntegerField(default=0, verbose_name="Остаток на складе")
    image = models.ImageField(
        upload_to='products/%Y/%m/%d', 
        blank=True, 
        null=True,
        verbose_name="Изображение"
    )
    is_active = models.BooleanField(default=True, verbose_name="Активен")
    created = models.DateTimeField(auto_now_add=True, verbose_name="Дата создания")
    updated = models.DateTimeField(auto_now=True, verbose_name="Дата обновления")

    class Meta:
        ordering = ('-created',)
        verbose_name = "Товар"
        verbose_name_plural = "Товары"
        indexes = [
            models.Index(fields=['name']),
            models.Index(fields=['price']),
            models.Index(fields=['-created']),
        ]

    def __str__(self):
        return self.name
    
    @property
    def in_stock(self):
        """Есть ли товар в наличии"""
        return self.stock > 0


class Profile(models.Model):
    """Профиль пользователя"""
    user = models.OneToOneField(
        User, 
        on_delete=models.CASCADE, 
        related_name='profile'
    )
    phone = models.CharField(
        max_length=20, 
        blank=True,
        verbose_name="Телефон (+993)"
    )
    otp_code = models.CharField(max_length=6, blank=True, null=True)
    otp_created_at = models.DateTimeField(null=True, blank=True)
    avatar = models.ImageField(
        upload_to='avatars/', 
        blank=True, 
        null=True,
        verbose_name="Аватар"
    )
    
    class Meta:
        verbose_name = "Профиль"
        verbose_name_plural = "Профили"
    
    def __str__(self):
        return f"Профиль {self.user.username}"


@receiver(post_save, sender=User)
def create_user_profile(sender, instance, created, **kwargs):
    """Автоматическое создание профиля при создании пользователя"""
    if created:
        Profile.objects.create(user=instance)


@receiver(post_save, sender=User)
def save_user_profile(sender, instance, **kwargs):
    """Сохранение профиля при сохранении пользователя"""
    if hasattr(instance, 'profile'):
        instance.profile.save()


class Order(models.Model):
    """Заказы"""
    
    class OrderStatus(models.TextChoices):
        PENDING = 'pending', 'Ожидает обработки'
        CONFIRMED = 'confirmed', 'Подтвержден'
        PROCESSING = 'processing', 'В обработке'
        SHIPPED = 'shipped', 'Отправлен'
        DELIVERED = 'delivered', 'Доставлен'
        CANCELLED = 'cancelled', 'Отменен'
    
    # Генерируем читаемый номер заказа
    order_number = models.CharField(
        max_length=20, 
        unique=True, 
        editable=False,
        verbose_name="Номер заказа"
    )
    user = models.ForeignKey(
        User, 
        related_name='orders', 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True,
        verbose_name="Пользователь"
    )
    
    # Данные получателя
    first_name = models.CharField(max_length=100, verbose_name="Имя")
    last_name = models.CharField(max_length=100, verbose_name="Фамилия")
    phone = models.CharField(max_length=20, verbose_name="Телефон")
    email = models.EmailField(blank=True, verbose_name="Email")
    address = models.TextField(verbose_name="Адрес доставки")
    
    # Статус и суммы
    status = models.CharField(
        max_length=20,
        choices=OrderStatus.choices,
        default=OrderStatus.PENDING,
        verbose_name="Статус"
    )
    total_amount = models.DecimalField(
        max_digits=10, 
        decimal_places=2,
        validators=[MinValueValidator(Decimal('0.00'))],
        verbose_name="Общая сумма"
    )
    
    # Комментарий к заказу
    note = models.TextField(blank=True, verbose_name="Комментарий")
    
    # Даты
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Дата создания")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Дата обновления")
    
    class Meta:
        verbose_name = "Заказ"
        verbose_name_plural = "Заказы"
        ordering = ['-created_at']
    
    def __str__(self):
        return f"Заказ #{self.order_number}"
    
    def save(self, *args, **kwargs):
        """Генерация номера заказа при создании"""
        if not self.order_number:
            # Формат: NS-YYYYMMDD-XXXX
            from django.utils import timezone
            import random
            date_str = timezone.now().strftime('%Y%m%d')
            random_str = ''.join([str(random.randint(0, 9)) for _ in range(4)])
            self.order_number = f"NS-{date_str}-{random_str}"
        super().save(*args, **kwargs)
    
    @property
    def items_count(self):
        """Количество позиций в заказе"""
        return self.items.count()
    
    def get_total(self):
        """Пересчитать общую сумму заказа"""
        total = sum(item.get_cost() for item in self.items.all())
        return total


class OrderItem(models.Model):
    """Позиции заказа (товары в заказе)"""
    order = models.ForeignKey(
        Order, 
        related_name='items', 
        on_delete=models.CASCADE,
        verbose_name="Заказ"
    )
    product = models.ForeignKey(
        Product, 
        related_name='order_items', 
        on_delete=models.SET_NULL,
        null=True,
        verbose_name="Товар"
    )
    # Сохраняем данные товара на момент заказа
    product_name = models.CharField(max_length=255, verbose_name="Название товара")
    price = models.DecimalField(
        max_digits=10, 
        decimal_places=2,
        verbose_name="Цена за единицу"
    )
    quantity = models.PositiveIntegerField(
        default=1,
        validators=[MinValueValidator(1)],
        verbose_name="Количество"
    )
    
    class Meta:
        verbose_name = "Позиция заказа"
        verbose_name_plural = "Позиции заказа"
    
    def __str__(self):
        return f"{self.product_name} x {self.quantity}"
    
    def get_cost(self):
        """Стоимость позиции (цена * количество)"""
        return self.price * self.quantity


class Favorite(models.Model):
    """Избранные товары пользователя"""
    user = models.ForeignKey(
        User, 
        related_name='favorites', 
        on_delete=models.CASCADE,
        verbose_name="Пользователь"
    )
    product = models.ForeignKey(
        Product, 
        related_name='favorited_by', 
        on_delete=models.CASCADE,
        verbose_name="Товар"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        verbose_name = "Избранное"
        verbose_name_plural = "Избранные"
        unique_together = ('user', 'product')  # Один товар один раз
    
    def __str__(self):
        return f"{self.user.username} -> {self.product.name}"