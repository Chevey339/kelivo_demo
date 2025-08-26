import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/search/search_service.dart';
import '../providers/settings_provider.dart';
import '../icons/lucide_adapter.dart';

class SearchServicesPage extends StatefulWidget {
  const SearchServicesPage({super.key});

  @override
  State<SearchServicesPage> createState() => _SearchServicesPageState();
}

class _SearchServicesPageState extends State<SearchServicesPage> {
  bool _isEditing = false;
  List<SearchServiceOptions> _services = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _services = List.from(settings.searchServices);
    _selectedIndex = settings.searchServiceSelected;
  }

  void _addService() {
    showDialog(
      context: context,
      builder: (context) => _AddServiceDialog(
        onAdd: (service) {
          setState(() {
            _services.add(service);
          });
          _saveChanges();
        },
      ),
    );
  }

  void _editService(int index) {
    final service = _services[index];
    showDialog(
      context: context,
      builder: (context) => _EditServiceDialog(
        service: service,
        onSave: (updated) {
          setState(() {
            _services[index] = updated;
          });
          _saveChanges();
        },
      ),
    );
  }

  void _deleteService(int index) {
    if (_services.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one search service is required')),
      );
      return;
    }
    
    setState(() {
      _services.removeAt(index);
      if (_selectedIndex >= _services.length) {
        _selectedIndex = _services.length - 1;
      } else if (_selectedIndex > index) {
        _selectedIndex--;
      }
    });
    _saveChanges();
  }

  void _selectService(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _saveChanges();
  }

  void _saveChanges() {
    final settings = context.read<SettingsProvider>();
    context.read<SettingsProvider>().updateSettings(
      settings.copyWith(
        searchServices: _services,
        searchServiceSelected: _selectedIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Lucide.ArrowLeft, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(zh ? '搜索服务' : 'Search Services'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Lucide.Check : Lucide.Edit),
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Common Search Options
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  zh ? '搜索设置' : 'Search Settings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildCommonOptions(),
              ],
            ),
          ),
          
          // Service List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _services.length,
              itemBuilder: (context, index) {
                return _buildServiceCard(index);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _isEditing
          ? FloatingActionButton(
              onPressed: _addService,
              child: Icon(Lucide.Plus),
            )
          : null,
    );
  }

  Widget _buildCommonOptions() {
    final settings = context.watch<SettingsProvider>();
    final commonOptions = settings.searchCommonOptions;
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(zh ? '最大结果数' : 'Max Results'),
            Row(
              children: [
                IconButton(
                  icon: Icon(Lucide.Minus),
                  onPressed: commonOptions.resultSize > 1 ? () {
                    context.read<SettingsProvider>().updateSettings(
                      settings.copyWith(
                        searchCommonOptions: SearchCommonOptions(
                          resultSize: commonOptions.resultSize - 1,
                          timeout: commonOptions.timeout,
                        ),
                      ),
                    );
                  } : null,
                ),
                Text('${commonOptions.resultSize}'),
                IconButton(
                  icon: Icon(Lucide.Plus),
                  onPressed: commonOptions.resultSize < 20 ? () {
                    context.read<SettingsProvider>().updateSettings(
                      settings.copyWith(
                        searchCommonOptions: SearchCommonOptions(
                          resultSize: commonOptions.resultSize + 1,
                          timeout: commonOptions.timeout,
                        ),
                      ),
                    );
                  } : null,
                ),
              ],
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(zh ? '超时时间（秒）' : 'Timeout (seconds)'),
            Row(
              children: [
                IconButton(
                  icon: Icon(Lucide.Minus),
                  onPressed: commonOptions.timeout > 1000 ? () {
                    context.read<SettingsProvider>().updateSettings(
                      settings.copyWith(
                        searchCommonOptions: SearchCommonOptions(
                          resultSize: commonOptions.resultSize,
                          timeout: commonOptions.timeout - 1000,
                        ),
                      ),
                    );
                  } : null,
                ),
                Text('${commonOptions.timeout ~/ 1000}'),
                IconButton(
                  icon: Icon(Lucide.Plus),
                  onPressed: commonOptions.timeout < 30000 ? () {
                    context.read<SettingsProvider>().updateSettings(
                      settings.copyWith(
                        searchCommonOptions: SearchCommonOptions(
                          resultSize: commonOptions.resultSize,
                          timeout: commonOptions.timeout + 1000,
                        ),
                      ),
                    );
                  } : null,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildServiceCard(int index) {
    final service = _services[index];
    final isSelected = index == _selectedIndex;
    final theme = Theme.of(context);
    final searchService = SearchService.getService(service);
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    
    return GestureDetector(
      onTap: () => _selectService(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Service Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getServiceIcon(service),
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              
              // Service Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      searchService.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    searchService.description(context),
                    if (_getServiceStatus(service) != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getServiceStatus(service) == (zh ? '已配置' : 'Configured')
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getServiceStatus(service)!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _getServiceStatus(service) == (zh ? '已配置' : 'Configured')
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Actions
              if (_isEditing) ...[
                IconButton(
                  icon: Icon(Lucide.Edit),
                  onPressed: () => _editService(index),
                ),
                IconButton(
                  icon: Icon(Lucide.Trash2),
                  onPressed: () => _deleteService(index),
                ),
              ] else if (isSelected) ...[
                Icon(
                  Lucide.Check,
                  color: theme.colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getServiceIcon(SearchServiceOptions service) {
    if (service is BingLocalOptions) return Lucide.Search;
    if (service is TavilyOptions) return Lucide.Sparkles;
    if (service is ExaOptions) return Lucide.Brain;
    if (service is ZhipuOptions) return Lucide.Languages;
    if (service is SearXNGOptions) return Lucide.Shield;
    if (service is LinkUpOptions) return Lucide.Link2;
    if (service is BraveOptions) return Lucide.Shield;
    if (service is MetasoOptions) return Lucide.Compass;
    return Lucide.Search;
  }

  String? _getServiceStatus(SearchServiceOptions service) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    if (service is BingLocalOptions) return null;
    if (service is TavilyOptions) return service.apiKey.isNotEmpty ? (zh ? '已配置' : 'Configured') : (zh ? '需要 API Key' : 'API Key Required');
    if (service is ExaOptions) return service.apiKey.isNotEmpty ? (zh ? '已配置' : 'Configured') : (zh ? '需要 API Key' : 'API Key Required');
    if (service is ZhipuOptions) return service.apiKey.isNotEmpty ? (zh ? '已配置' : 'Configured') : (zh ? '需要 API Key' : 'API Key Required');
    if (service is SearXNGOptions) return service.url.isNotEmpty ? (zh ? '已配置' : 'Configured') : (zh ? '需要 URL' : 'URL Required');
    if (service is LinkUpOptions) return service.apiKey.isNotEmpty ? (zh ? '已配置' : 'Configured') : (zh ? '需要 API Key' : 'API Key Required');
    if (service is BraveOptions) return service.apiKey.isNotEmpty ? (zh ? '已配置' : 'Configured') : (zh ? '需要 API Key' : 'API Key Required');
    if (service is MetasoOptions) return service.apiKey.isNotEmpty ? (zh ? '已配置' : 'Configured') : (zh ? '需要 API Key' : 'API Key Required');
    return null;
  }
}

// Add Service Dialog
class _AddServiceDialog extends StatefulWidget {
  final Function(SearchServiceOptions) onAdd;

  const _AddServiceDialog({required this.onAdd});

  @override
  State<_AddServiceDialog> createState() => _AddServiceDialogState();
}

class _AddServiceDialogState extends State<_AddServiceDialog> {
  String _selectedType = 'bing_local';
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    
    return AlertDialog(
      title: Text(zh ? '添加搜索服务' : 'Add Search Service'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                  labelText: zh ? '服务类型' : 'Service Type',
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 'bing_local', child: Text('Bing (${zh ? '本地' : 'Local'})')),
                  const DropdownMenuItem(value: 'tavily', child: Text('Tavily')),
                  const DropdownMenuItem(value: 'exa', child: Text('Exa')),
                  DropdownMenuItem(value: 'zhipu', child: Text('Zhipu (${zh ? '智谱' : ''})')),
                  const DropdownMenuItem(value: 'searxng', child: Text('SearXNG')),
                  const DropdownMenuItem(value: 'linkup', child: Text('LinkUp')),
                  const DropdownMenuItem(value: 'brave', child: Text('Brave Search')),
                  DropdownMenuItem(value: 'metaso', child: Text('Metaso (${zh ? '秘塔' : ''})')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                    _controllers.clear();
                  });
                },
              ),
              const SizedBox(height: 16),
              ..._buildFieldsForType(_selectedType),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(zh ? '取消' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final service = _createService();
              widget.onAdd(service);
              Navigator.pop(context);
            }
          },
          child: Text(zh ? '添加' : 'Add'),
        ),
      ],
    );
  }

  List<Widget> _buildFieldsForType(String type) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    
    switch (type) {
      case 'bing_local':
        return [];
      case 'tavily':
      case 'exa':
      case 'zhipu':
      case 'linkup':
      case 'brave':
      case 'metaso':
        _controllers['apiKey'] ??= TextEditingController();
        return [
          TextFormField(
            controller: _controllers['apiKey'],
            decoration: const InputDecoration(
              labelText: 'API Key',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return zh ? 'API Key 必填' : 'API Key is required';
              }
              return null;
            },
          ),
        ];
      case 'searxng':
        _controllers['url'] ??= TextEditingController();
        _controllers['engines'] ??= TextEditingController();
        _controllers['language'] ??= TextEditingController();
        _controllers['username'] ??= TextEditingController();
        _controllers['password'] ??= TextEditingController();
        return [
          TextFormField(
            controller: _controllers['url'],
            decoration: InputDecoration(
              labelText: zh ? '实例 URL' : 'Instance URL',
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return zh ? 'URL 必填' : 'URL is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _controllers['engines'],
            decoration: InputDecoration(
              labelText: zh ? '搜索引擎（可选）' : 'Engines (optional)',
              hintText: 'google,duckduckgo',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _controllers['language'],
            decoration: InputDecoration(
              labelText: zh ? '语言（可选）' : 'Language (optional)',
              hintText: 'en-US',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _controllers['username'],
            decoration: InputDecoration(
              labelText: zh ? '用户名（可选）' : 'Username (optional)',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _controllers['password'],
            obscureText: true,
            decoration: InputDecoration(
              labelText: zh ? '密码（可选）' : 'Password (optional)',
              border: const OutlineInputBorder(),
            ),
          ),
        ];
      default:
        return [];
    }
  }

  SearchServiceOptions _createService() {
    final uuid = const Uuid();
    final id = uuid.v4().substring(0, 8);
    
    switch (_selectedType) {
      case 'bing_local':
        return BingLocalOptions(id: id);
      case 'tavily':
        return TavilyOptions(
          id: id,
          apiKey: _controllers['apiKey']!.text,
        );
      case 'exa':
        return ExaOptions(
          id: id,
          apiKey: _controllers['apiKey']!.text,
        );
      case 'zhipu':
        return ZhipuOptions(
          id: id,
          apiKey: _controllers['apiKey']!.text,
        );
      case 'searxng':
        return SearXNGOptions(
          id: id,
          url: _controllers['url']!.text,
          engines: _controllers['engines']!.text,
          language: _controllers['language']!.text,
          username: _controllers['username']!.text,
          password: _controllers['password']!.text,
        );
      case 'linkup':
        return LinkUpOptions(
          id: id,
          apiKey: _controllers['apiKey']!.text,
        );
      case 'brave':
        return BraveOptions(
          id: id,
          apiKey: _controllers['apiKey']!.text,
        );
      case 'metaso':
        return MetasoOptions(
          id: id,
          apiKey: _controllers['apiKey']!.text,
        );
      default:
        return BingLocalOptions(id: id);
    }
  }
}

// Edit Service Dialog
class _EditServiceDialog extends StatefulWidget {
  final SearchServiceOptions service;
  final Function(SearchServiceOptions) onSave;

  const _EditServiceDialog({
    required this.service,
    required this.onSave,
  });

  @override
  State<_EditServiceDialog> createState() => _EditServiceDialogState();
}

class _EditServiceDialogState extends State<_EditServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final service = widget.service;
    if (service is TavilyOptions) {
      _controllers['apiKey'] = TextEditingController(text: service.apiKey);
    } else if (service is ExaOptions) {
      _controllers['apiKey'] = TextEditingController(text: service.apiKey);
    } else if (service is ZhipuOptions) {
      _controllers['apiKey'] = TextEditingController(text: service.apiKey);
    } else if (service is SearXNGOptions) {
      _controllers['url'] = TextEditingController(text: service.url);
      _controllers['engines'] = TextEditingController(text: service.engines);
      _controllers['language'] = TextEditingController(text: service.language);
      _controllers['username'] = TextEditingController(text: service.username);
      _controllers['password'] = TextEditingController(text: service.password);
    } else if (service is LinkUpOptions) {
      _controllers['apiKey'] = TextEditingController(text: service.apiKey);
    } else if (service is BraveOptions) {
      _controllers['apiKey'] = TextEditingController(text: service.apiKey);
    } else if (service is MetasoOptions) {
      _controllers['apiKey'] = TextEditingController(text: service.apiKey);
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final searchService = SearchService.getService(widget.service);
    
    return AlertDialog(
      title: Text('${zh ? '编辑' : 'Edit'} ${searchService.name}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _buildFields(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(zh ? '取消' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final updated = _updateService();
              widget.onSave(updated);
              Navigator.pop(context);
            }
          },
          child: Text(zh ? '保存' : 'Save'),
        ),
      ],
    );
  }

  List<Widget> _buildFields() {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final service = widget.service;
    
    if (service is BingLocalOptions) {
      return [Text(zh ? 'Bing 本地搜索不需要配置。' : 'No configuration required for Bing Local search.')];
    } else if (service is TavilyOptions || 
               service is ExaOptions || 
               service is ZhipuOptions ||
               service is LinkUpOptions ||
               service is BraveOptions ||
               service is MetasoOptions) {
      return [
        TextFormField(
          controller: _controllers['apiKey'],
          decoration: const InputDecoration(
            labelText: 'API Key',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return zh ? 'API Key 必填' : 'API Key is required';
            }
            return null;
          },
        ),
      ];
    } else if (service is SearXNGOptions) {
      return [
        TextFormField(
          controller: _controllers['url'],
          decoration: InputDecoration(
            labelText: zh ? '实例 URL' : 'Instance URL',
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return zh ? 'URL 必填' : 'URL is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _controllers['engines'],
          decoration: InputDecoration(
            labelText: zh ? '搜索引擎（可选）' : 'Engines (optional)',
            hintText: 'google,duckduckgo',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _controllers['language'],
          decoration: InputDecoration(
            labelText: zh ? '语言（可选）' : 'Language (optional)',
            hintText: 'en-US',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _controllers['username'],
          decoration: InputDecoration(
            labelText: zh ? '用户名（可选）' : 'Username (optional)',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _controllers['password'],
          obscureText: true,
          decoration: InputDecoration(
            labelText: zh ? '密码（可选）' : 'Password (optional)',
            border: const OutlineInputBorder(),
          ),
        ),
      ];
    }
    
    return [];
  }

  SearchServiceOptions _updateService() {
    final service = widget.service;
    
    if (service is TavilyOptions) {
      return TavilyOptions(
        id: service.id,
        apiKey: _controllers['apiKey']!.text,
      );
    } else if (service is ExaOptions) {
      return ExaOptions(
        id: service.id,
        apiKey: _controllers['apiKey']!.text,
      );
    } else if (service is ZhipuOptions) {
      return ZhipuOptions(
        id: service.id,
        apiKey: _controllers['apiKey']!.text,
      );
    } else if (service is SearXNGOptions) {
      return SearXNGOptions(
        id: service.id,
        url: _controllers['url']!.text,
        engines: _controllers['engines']!.text,
        language: _controllers['language']!.text,
        username: _controllers['username']!.text,
        password: _controllers['password']!.text,
      );
    } else if (service is LinkUpOptions) {
      return LinkUpOptions(
        id: service.id,
        apiKey: _controllers['apiKey']!.text,
      );
    } else if (service is BraveOptions) {
      return BraveOptions(
        id: service.id,
        apiKey: _controllers['apiKey']!.text,
      );
    } else if (service is MetasoOptions) {
      return MetasoOptions(
        id: service.id,
        apiKey: _controllers['apiKey']!.text,
      );
    }
    
    return service;
  }
}