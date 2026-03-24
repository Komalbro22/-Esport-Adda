import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';

class AdminProductForm extends StatefulWidget {
  final ShopProduct? existingProduct;
  const AdminProductForm({Key? key, this.existingProduct}) : super(key: key);

  @override
  State<AdminProductForm> createState() => _AdminProductFormState();
}

class _AdminProductFormState extends State<AdminProductForm> {
  final _formKey = GlobalKey<FormState>();
  final _shopService = ShopService();
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late TextEditingController _categoryController;
  late TextEditingController _imageController;

  bool _isDigital = true;
  bool _isActive = true;
  String _allowedWalletType = 'both';

  @override
  void initState() {
    super.initState();
    final p = widget.existingProduct;
    _nameController = TextEditingController(text: p?.name ?? '');
    _descController = TextEditingController(text: p?.description ?? '');
    _priceController = TextEditingController(text: p?.price.toString() ?? '');
    _categoryController = TextEditingController(text: p?.category ?? '');
    _imageController = TextEditingController(text: p?.imageUrl ?? '');

    if (p != null) {
      _isDigital = p.isDigital;
      _isActive = p.isActive;
      _allowedWalletType = p.allowedWalletType;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  void _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);

    try {
      final product = ShopProduct(
        id: widget.existingProduct?.id ?? '',
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        category: _categoryController.text.trim(),
        imageUrl: _imageController.text.trim(),
        isDigital: _isDigital,
        isActive: _isActive,
        allowedWalletType: _allowedWalletType,
      );

      if (widget.existingProduct != null) {
        await _shopService.updateProduct(product);
        StitchSnackbar.showSuccess(context, 'Product updated successfully!');
      } else {
        await _shopService.createProduct(product);
        StitchSnackbar.showSuccess(context, 'Product created successfully!');
      }
      
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to save product: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchTheme.background,
      appBar: AppBar(
        title: Text(widget.existingProduct != null ? 'Edit Product' : 'Add Product'),
        backgroundColor: StitchTheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StitchInput(
                controller: _nameController,
                label: 'Product Name',
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              StitchInput(
                controller: _priceController,
                label: 'Price (₹)',
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  if (double.tryParse(val) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              StitchInput(
                controller: _descController,
                label: 'Description',
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              StitchInput(
                controller: _categoryController,
                label: 'Category',
              ),
              const SizedBox(height: 16),
              StitchInput(
                controller: _imageController,
                label: 'Image URL',
                hintText: 'https://...',
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _allowedWalletType,
                      dropdownColor: StitchTheme.surface,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Allowed Wallet Type',
                        labelStyle: TextStyle(color: StitchTheme.textMuted),
                        filled: true,
                        fillColor: StitchTheme.surfaceHighlight,
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                      ),
                      onChanged: (String? newValue) {
                        setState(() {
                          _allowedWalletType = newValue!;
                        });
                      },
                      items: const [
                        DropdownMenuItem(value: 'both', child: Text('Both (Deposit First)')),
                        DropdownMenuItem(value: 'deposit', child: Text('Deposit Wallet Only')),
                        DropdownMenuItem(value: 'winning', child: Text('Winning Wallet Only')),
                        DropdownMenuItem(value: 'global', child: Text('Global Default')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text('Digital Product (Requires Delivery Code)', style: TextStyle(color: Colors.white)),
                value: _isDigital,
                activeColor: StitchTheme.primary,
                onChanged: (val) => setState(() => _isDigital = val),
              ),
              SwitchListTile(
                title: const Text('Active', style: TextStyle(color: Colors.white)),
                value: _isActive,
                activeColor: StitchTheme.success,
                onChanged: (val) => setState(() => _isActive = val),
              ),
              const SizedBox(height: 32),
              StitchButton(
                text: 'Save Product',
                isLoading: _isSaving,
                onPressed: _saveProduct,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
