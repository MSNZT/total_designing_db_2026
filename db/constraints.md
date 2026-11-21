Схема: `sorokin_food`.

Таблица заказов названа `orders` вместо `order`, так как `ORDER` является ключевым словом - (BR-13.1).

Параметр `p_rating` сохранён в процедуре `add_product()` для соблюдения FOOD-104. При создании блюда рейтинг устанавливается в NULL, поскольку согласно BR-9.6–9.7 он является вычисляемым значением и формируется исключительно на основании отзывов.

## Enum-типы

| Тип | Значения | BR |
|---|---|---|
| `restaurant_status` | `активен`, `неактивен` | BR-4.3 |
| `dish_status` | `доступно`, `нет_в_наличии`, `архив` | BR-5.5 |
| `courier_status` | `свободен`, `занят`, `на_доставке`, `уволен` | BR-6.2 |
| `order_status` | `создан`, `готовится`, `в_доставке`, `доставлен`, `отменён` | BR-7.7 |
| `order_pay_status` | `ожидает`, `оплачен`, `ошибка` | BR-7.9 |
| `payment_status` | `успех`, `ошибка`, `в_обработке` | BR-8.2 |
| `payment_type` | `карта`, `наличные`, `безнал` | BR-8.2 |
| `entity_type` | `блюдо`, `ресторан`, `заказ` | BR-9.1 |

## Ловушки

### 1. Таблица `payment`

В `payment` добавлены `payment_type`, `status`, `transaction_id`, `transaction_timestamp` и `amount` — BR-8.2. Они нужны для хранения типа, результата, идентификатора, времени и суммы каждой попытки оплаты.

Тип оплаты хранится в `payment`, а не в `orders`, так как у одного заказа могут быть попытки оплаты разными способами (BR-8.6).

`transaction_id` имеет тип `VARCHAR(255)` и ограничение `UNIQUE`, потому что это уникальный внешний идентификатор транзакции (BR-8.3). Равенство `payment.amount` и `orders.total_amount` проверяет триггер (BR-8.4). Для `payment` создан уникальный индекс с условием `WHERE status = 'успех'`, он разрешает несколько попыток оплаты заказа, но не более одной успешной (BR-8.1).

### 2. Адрес доставки

В `orders` используется составной FK `(client_id, address_id)` → `client_address(client_id, address_id)` — BR-7.4. Он разрешает доставку только по адресу, привязанному к клиенту заказа.

### 3. Блюда одного ресторана

Триггеры проверяют, что `product.restaurant_id` совпадает с `orders.restaurant_id` для каждого блюда в `order_structure` (BR-7.3). Проверка также выполняется при изменении ресторана у заказа или блюда.

### 4. Отзывы

В `review` используются `entity_type` и `entity_id`, так как отзыв может относиться к блюду, ресторану или заказу (BR-9.1), обычный FK на `entity_id` не используется, потому что он ссылается на разные таблицы.

Триггер проверяет, что отзыв оставлен на собственный заказ клиента и связан с блюдом или рестораном этого заказа (BR-9.2).

## CHECK-ограничения

| Таблица | Столбец | Условие | BR | Обоснование |
|---|---|---|---|---|
| `restaurant` | `work_start`, `work_end` | `work_end > work_start` | BR-4.4 | Ресторан закрывается позже, чем открывается. |
| `restaurant` | `rating` | `rating BETWEEN 0 AND 5` | BR-4.2 | Рейтинг от 0 до 5. |
| `product` | `price` | `price >= 0` | BR-5.3 | Цена не может быть отрицательной. |
| `product` | `rating` | `rating BETWEEN 0 AND 5` | BR-5.4 | Рейтинг от 0 до 5. |
| `courier` | `coefficient` | `coefficient BETWEEN 0.1 AND 0.5` | BR-6.4 | Коэффициент от 0.1 до 0.5. |
| `courier` | `status`, `dismissal_date` | `status <> 'уволен' OR dismissal_date IS NOT NULL` | BR-6.3 | У уволенного курьера должна быть дата увольнения. |
| `courier` | `hire_date`, `dismissal_date` | `dismissal_date >= hire_date` | BR-6.1 | Дата увольнения не может быть раньше найма. |
| `courier_pay` | `month` | `month BETWEEN 1 AND 12` | BR-10.2 | Зарплата рассчитывается по календарным месяцам. |
| `courier_pay` | `amount` | `amount >= 0` | BR-10.4 | Зарплата не может быть отрицательной. |
| `courier_pay` | `coefficient_used` | `coefficient_used BETWEEN 0.1 AND 0.5` | BR-6.4, BR-10.2 | Сохраняется допустимый коэффициент расчёта. |
| `orders` | `delivery_timestamp`, `order_timestamp` | `delivery_timestamp >= order_timestamp` | BR-7.13 | Доставка не может завершиться раньше создания заказа. |
| `orders` | `status`, `delivery_timestamp` | `status <> 'доставлен' OR delivery_timestamp IS NOT NULL` | BR-7.12 | У доставленного заказа есть время доставки. |
| `orders` | `total_amount` | `total_amount >= 1000` | BR-7.11 | Общая сумма заказа не менее 1000 ₽. |
| `payment` | `amount` | `amount >= 1000` | BR-7.11, BR-8.4 | Платёж равен общей сумме заказа, для которой установлен минимум 1000 ₽. |
| `order_structure` | `quantity` | `quantity > 0` | BR-7.15 | Количество положительное, в том числе дробное. |
| `review` | `rating` | `rating BETWEEN 1 AND 5` | BR-9.4 | Оценка в отзыве от 1 до 5. |

## UNIQUE-ограничения

| Таблица | Столбцы | BR | Обоснование |
|---|---|---|---|
| `client` | `login` | BR-2.2 | Логин клиента уникален. |
| `client` | `phone_number` | BR-2.2 | Телефон клиента уникален. |
| `restaurant` | `address_id` | BR-3.3 | Два ресторана не могут иметь один адрес. |
| `payment` | `transaction_id` | BR-8.3 | Идентификатор транзакции уникален. |
| `payment` | `order_id WHERE status = 'успех'` | BR-8.1 | У заказа не может быть двух успешных оплат. |
| `review` | `(order_id, entity_id, entity_type)` | BR-9.5 | На один объект в рамках заказа можно оставить один отзыв. |
| `client_address` | `(client_id, address_id)` — PK | BR-2.5 | Один адрес нельзя дважды привязать к клиенту. |
| `order_structure` | `(order_id, product_id)` — PK | BR-7.16 | Блюдо не может повторяться в одном заказе. |
| `courier_pay` | `(year, month, courier_id)` — PK | BR-10.3 | Одна запись о зарплате курьера за месяц. |

## FK-ограничения

| Таблица | Столбцы | → Таблица | BR | Обоснование |
|---|---|---|---|---|
| `client_address` | `client_id` | `client(client_id)` | BR-2.4 | Адрес привязан к существующему клиенту. |
| `client_address` | `address_id` | `address(address_id)` | BR-2.4 | Клиенту привязывается существующий адрес. |
| `restaurant` | `address_id` | `address(address_id)` | BR-3.3 | Ресторан ссылается на существующий адрес. |
| `product` | `product_category_id` | `product_category(product_category_id)` | BR-5.1 | Блюдо принадлежит существующей категории. |
| `product` | `restaurant_id` | `restaurant(restaurant_id)` | BR-5.1 | Блюдо принадлежит существующему ресторану. |
| `courier_pay` | `courier_id` | `courier(courier_id)` | BR-10.2 | Выплата относится к существующему курьеру. |
| `orders` | `courier_id` | `courier(courier_id)` | BR-7.5 | Заказ связан с существующим курьером. |
| `orders` | `client_id` | `client(client_id)` | BR-7.1 | Заказ оформляет существующий клиент. |
| `orders` | `address_id` | `address(address_id)` | BR-7.4 | Адрес доставки существует. |
| `orders` | `restaurant_id` | `restaurant(restaurant_id)` | BR-7.2 | Заказ относится к существующему ресторану. |
| `orders` | `(client_id, address_id)` | `client_address(client_id, address_id)` | BR-7.4 | Адрес доставки принадлежит клиенту заказа. |
| `payment` | `order_id` | `orders(order_id)` | BR-8.1 | Платёж относится к существующему заказу. |
| `order_structure` | `order_id` | `orders(order_id)` | BR-7.14 | Позиция относится к существующему заказу. |
| `order_structure` | `product_id` | `product(product_id)` | BR-7.14 | В позиции указано существующее блюдо. |
| `review` | `client_id` | `client(client_id)` | BR-9.2 | Отзыв относится к существующему клиенту. |
| `review` | `order_id` | `orders(order_id)` | BR-9.2 | Отзыв относится к существующему заказу. |

## NOT NULL

| Таблица | Столбцы | BR | Обоснование |
|---|---|---|---|
| `address` | `street`, `house_number` | BR-3.1 | Для адреса нужны улица и номер дома. |
| `client` | `login`, `password`, `phone_number` | BR-2.1 | Эти данные нужны для регистрации. |
| `restaurant` | `restaurant_name`, `description`, `inn`, `ogrn`, `checking_account` | BR-4.1, BR-4.5 | У ресторана должны быть название, описание и реквизиты. |
| `restaurant` | `work_start`, `work_end`, `status` | BR-4.3, BR-4.4 | Нужны график работы и статус. |
| `product` | `product_name`, `price`, `description`, `status` | BR-5.2 | Основные данные блюда обязательны. |
| `courier` | `fio`, `phone_number`, `status`, `hire_date`, `coefficient` | BR-6.1 | Основные данные курьера обязательны. |
| `orders` | `order_timestamp`, `order_amount`, `status`, `pay_status` | BR-7.1, BR-7.6, BR-7.8, BR-7.10 | У заказа должны быть дата, сумма и статусы. |
| `payment` | `payment_type`, `status`, `transaction_id`, `transaction_timestamp`, `amount` | BR-8.2 | Эти поля описывают попытку оплаты. |
| `review` | `review_timestamp`, `entity_id`, `entity_type`, `description`, `rating` | BR-9.1, BR-9.3 | Отзыв должен содержать объект, дату, текст и оценку. |

## NULL

| Таблица | Столбец | BR | Почему NULL |
|---|---|---|---|
| `address` | `apartment_office` | BR-3.2 | Квартира или офис есть не у каждого адреса. |
| `courier` | `dismissal_date` | BR-6.3 | У работающего курьера нет даты увольнения. |
| `orders` | `delivery_timestamp` | BR-7.12 | Доставка ещё может быть не завершена. |
| `product` | `photo_url` | BR-5.6 | Фотография необязательна. |
| `review` | `photo_url` | BR-9.3 | Фото к отзыву необязательно. |
| `product` | `rating` | BR-9.7 | Без отзывов рейтинг равен `NULL`. |
| `restaurant` | `rating` | BR-9.7 | Без отзывов рейтинг равен `NULL`. |

## DEFAULT и GENERATED

| Таблица | Столбец | Что | Обоснование |
|---|---|---|---|
| `address`, `client`, `restaurant`, `courier`, `product_category`, `product`, `orders`, `payment`, `review` | Соответствующий `*_id` | `DEFAULT exts.uuid_generate_v4()` | BR-11.1: UUID создаются на сервере. |
| `courier` | `coefficient` | `DEFAULT 0.1` | BR-6.5: начальный коэффициент курьера — 0.1. |
| `orders` | `commission` | `GENERATED ALWAYS AS (ROUND(order_amount * 0.10, 2)) STORED` | BR-1.4, BR-7.10: комиссия составляет 10% от суммы заказа. |
| `orders` | `total_amount` | `GENERATED ALWAYS AS (ROUND(order_amount * 1.10, 2)) STORED` | BR-1.5, BR-7.10: общая сумма включает комиссию. |

## Нормализация (3НФ)

Данные разделены по сущностям: клиенты, адреса, рестораны, блюда, заказы и оплаты хранятся в отдельных таблицах. В таблицах с составными ключами данные зависят от всего ключа, лишних зависимостей между неключевыми полями нет.

`orders.commission` и `orders.total_amount` вычисляются автоматически через `GENERATED`, поэтому вручную их изменить нельзя (BR-7.10). Рейтинги `product` и `restaurant` хранятся отдельно для удобства получения данных и пересчитываются триггером `rating_change()` (BR-9.6, BR-9.7). Это осознанная денормализация.

Для отзывов используются `entity_type` и `entity_id`. Корректность связи проверяется триггером (BR-9.1, BR-9.2).
