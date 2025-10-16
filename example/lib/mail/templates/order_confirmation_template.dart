// lib/mail/templates/order_confirmation_template.dart

class OrderConfirmationTemplate extends FlintEmailTemplate {
  final String orderNumber;
  final DateTime orderDate;
  final double orderTotal;
  final List<OrderItem> items;
  final String? trackingNumber;
  final String? estimatedDelivery;

  OrderConfirmationTemplate({
    required super.recipientName,
    required super.recipientEmail,
    required this.orderNumber,
    required this.orderDate,
    required this.orderTotal,
    required this.items,
    this.trackingNumber,
    this.estimatedDelivery,
    super.theme = const FlintTheme(),
  });

  @override
  FlintWidget buildContent() {
    return FlintBox(
      padding: EdgeInsets.all(24),
      children: [
        // Order confirmation header
        _buildHeader(),

        // Order details
        _buildOrderDetails(),

        // Items list
        _buildItemsList(),

        // Order total
        _buildOrderTotal(),

        // Shipping info (if available)
        if (trackingNumber != null) _buildShippingInfo(),

        // Next steps
        _buildNextSteps(),
      ],
    );
  }

  FlintWidget _buildHeader() {
    return FlintBox(
      children: [
        FlintText(
          'Order Confirmation ✅',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: '#1a1a1a',
          ),
          align: TextAlign.center,
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 8),
          children: [
            FlintText(
              'Thank you for your order, $recipientName!',
              style: TextStyle(
                fontSize: 16,
                color: '#666666',
              ),
              align: TextAlign.center,
            ),
          ],
        ),
      ],
    );
  }

  FlintWidget _buildOrderDetails() {
    return FlintBox(
      margin: EdgeInsets.only(top: 24),
      padding: EdgeInsets.all(16),
      backgroundColor: '#f8f9fa',
      borderRadius: BorderRadius.circular(8),
      children: [
        FlintRow(
          columnWidths: [50, 50],
          children: [
            FlintBox(
              children: [
                FlintText(
                  'Order Number',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: '#666666',
                  ),
                ),
                FlintBox(
                  margin: EdgeInsets.only(top: 4),
                  children: [
                    FlintText(
                      orderNumber,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: '#1a1a1a',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            FlintBox(
              children: [
                FlintText(
                  'Order Date',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: '#666666',
                  ),
                ),
                FlintBox(
                  margin: EdgeInsets.only(top: 4),
                  children: [
                    FlintText(
                      '${orderDate.day}/${orderDate.month}/${orderDate.year}',
                      style: TextStyle(
                        fontSize: 14,
                        color: '#1a1a1a',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  FlintWidget _buildItemsList() {
    return FlintBox(
      margin: EdgeInsets.only(top: 24),
      children: [
        FlintText(
          'Order Items',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: '#1a1a1a',
          ),
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 16),
          children: items.map((item) => _buildOrderItem(item)).toList(),
        ),
      ],
    );
  }

  FlintWidget _buildOrderItem(OrderItem item) {
    return FlintBox(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      border: BoxBorder.all(color: '#e0e0e0'),
      borderRadius: BorderRadius.circular(6),
      children: [
        FlintRow(
          columnWidths: [70, 30],
          children: [
            FlintBox(
              children: [
                FlintText(
                  item.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: '#1a1a1a',
                  ),
                ),
                if (item.description != null)
                  FlintBox(
                    margin: EdgeInsets.only(top: 4),
                    children: [
                      FlintText(
                        item.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: '#666666',
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            FlintBox(
              children: [
                FlintText(
                  '\$${item.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: '#1a1a1a',
                  ),
                  align: TextAlign.right,
                ),
                FlintBox(
                  margin: EdgeInsets.only(top: 4),
                  children: [
                    FlintText(
                      'Qty: ${item.quantity}',
                      style: TextStyle(
                        fontSize: 12,
                        color: '#666666',
                      ),
                      align: TextAlign.right,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  FlintWidget _buildOrderTotal() {
    return FlintBox(
      margin: EdgeInsets.only(top: 24),
      padding: EdgeInsets.all(16),
      backgroundColor: '#f8f9fa',
      borderRadius: BorderRadius.circular(8),
      children: [
        FlintRow(
          columnWidths: [50, 50],
          children: [
            FlintText(
              'Total Amount',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: '#1a1a1a',
              ),
            ),
            FlintText(
              '\$${orderTotal.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
              align: TextAlign.right,
            ),
          ],
        ),
      ],
    );
  }

  FlintWidget _buildShippingInfo() {
    return FlintBox(
      margin: EdgeInsets.only(top: 24),
      padding: EdgeInsets.all(16),
      backgroundColor: '#e8f5e8',
      border: BoxBorder.all(color: '#c8e6c9'),
      borderRadius: BorderRadius.circular(8),
      children: [
        FlintText(
          '🚚 Shipping Information',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: '#2e7d32',
          ),
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 12),
          children: [
            FlintRow(
              columnWidths: [50, 50],
              children: [
                FlintBox(
                  children: [
                    FlintText(
                      'Tracking Number',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: '#666666',
                      ),
                    ),
                    FlintBox(
                      margin: EdgeInsets.only(top: 4),
                      children: [
                        FlintText(
                          trackingNumber!,
                          style: TextStyle(
                            fontSize: 14,
                            color: '#1a1a1a',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (estimatedDelivery != null)
                  FlintBox(
                    children: [
                      FlintText(
                        'Estimated Delivery',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: '#666666',
                        ),
                      ),
                      FlintBox(
                        margin: EdgeInsets.only(top: 4),
                        children: [
                          FlintText(
                            estimatedDelivery!,
                            style: TextStyle(
                              fontSize: 14,
                              color: '#1a1a1a',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  FlintWidget _buildNextSteps() {
    return FlintBox(
      margin: EdgeInsets.only(top: 24),
      children: [
        FlintText(
          'What\'s Next?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: '#1a1a1a',
          ),
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 12),
          children: [
            FlintText(
              '• You will receive a shipping confirmation email when your order ships\n'
              '• Track your order using the tracking number provided\n'
              '• Contact support if you have any questions about your order',
              style: TextStyle(
                fontSize: 14,
                color: '#666666',
                lineHeight: 1.6,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class OrderItem {
  final String name;
  final String? description;
  final int quantity;
  final double price;

  OrderItem({
    required this.name,
    this.description,
    required this.quantity,
    required this.price,
  });
}
