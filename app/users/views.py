from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.contrib.auth import get_user_model
from django.utils import timezone
from datetime import timedelta
from .serializers import UserSerializer, SubscriptionPlanSerializer
from .models import SubscriptionPlan, Subscription

User = get_user_model()


@api_view(['GET', 'PUT', 'PATCH', 'DELETE'])
@permission_classes([IsAuthenticated])
def UserProfileView(request):
    """
    GET: Получить профиль пользователя
    PUT/PATCH: Обновить профиль пользователя (first_name, last_name, birth_date)
    DELETE: Удалить аккаунт пользователя
    """
    user = request.user
    
    if request.method == 'GET':
        serializer = UserSerializer(user)
        return Response(serializer.data, status=status.HTTP_200_OK)
    
    elif request.method in ['PUT', 'PATCH']:
        # Разрешаем обновление только определенных полей
        allowed_fields = ['first_name', 'last_name', 'birth_date']
        data = {k: v for k, v in request.data.items() if k in allowed_fields}
        
        serializer = UserSerializer(user, data=data, partial=request.method == 'PATCH')
        
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    elif request.method == 'DELETE':
        # Удаление аккаунта пользователя
        user.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
    
    return Response(
        {'error': 'Method not allowed'}, 
        status=status.HTTP_405_METHOD_NOT_ALLOWED
    )


@api_view(['GET'])
@permission_classes([])  # Public endpoint - no authentication required
def SubscriptionPlansView(request):
    """
    GET: Get list of active subscription plans.
    Returns all active subscription plans available for purchase.
    """
    plans = SubscriptionPlan.objects.filter(is_active=True).order_by('price')
    serializer = SubscriptionPlanSerializer(plans, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def PurchaseSubscriptionView(request):
    """
    POST: Purchase a subscription plan.
    Requires: plan_id in request body.
    Validates user balance and creates subscription with expires_at calculated from plan.days.
    """
    user = request.user
    plan_id = request.data.get('plan_id')
    
    if not plan_id:
        return Response(
            {'success': False, 'error': 'plan_id is required'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    try:
        plan = SubscriptionPlan.objects.get(id=plan_id, is_active=True)
    except SubscriptionPlan.DoesNotExist:
        return Response(
            {'success': False, 'error': 'Subscription plan not found or inactive'},
            status=status.HTTP_404_NOT_FOUND
        )
    
    # Validate user balance
    if user.balance < plan.price:
        return Response(
            {
                'success': False,
                'error': f'Баланси шумо кифоя нест. Баланс: {user.balance}, Нарх: {plan.price}'
            },
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Calculate expires_at based on plan.days
    # If user has an active subscription, extend from expires_at, otherwise from now
    now = timezone.now()
    existing_subscription = Subscription.objects.filter(
        user=user,
        is_active=True,
        expires_at__gt=now
    ).order_by('-expires_at').first()
    
    if existing_subscription and existing_subscription.expires_at > now:
        # Extend from existing expiration date
        expires_at = existing_subscription.expires_at + timedelta(days=plan.days)
    else:
        # Start from now
        expires_at = now + timedelta(days=plan.days)
    
    # Deduct balance
    user.balance -= plan.price
    user.save()
    
    # Create subscription
    subscription = Subscription.objects.create(
        user=user,
        plan=plan,
        expires_at=expires_at,
        is_active=True
    )
    
    # Deactivate old subscriptions (optional - if you want only one active subscription)
    Subscription.objects.filter(
        user=user,
        is_active=True
    ).exclude(id=subscription.id).update(is_active=False)
    
    return Response(
        {
            'success': True,
            'message': f'Обунаи "{plan.name}" бо муваффақият харида шуд',
            'subscription': {
                'id': subscription.id,
                'plan_name': plan.name,
                'expires_at': subscription.expires_at.isoformat(),
            },
            'balance': float(user.balance),
        },
        status=status.HTTP_201_CREATED
    )

