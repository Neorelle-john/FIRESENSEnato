import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:firesense/services/notification_service.dart';


class FirePredictionService {
  static final FirePredictionService _instance =
      FirePredictionService._internal();
  factory FirePredictionService() => _instance;
  FirePredictionService._internal();

  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  StreamSubscription<DatabaseEvent>? _realtimeListener;
  Map<String, StreamSubscription<DatabaseEvent>> _deviceListeners = {};
  bool _isListening = false;
  Timer? _debounceTimer;

  Map<String, double?> _lastSensorValues = {
    'mq2': null,
    'mq9': null,
    'flame': null,
  };

  Map<String, String?> _previousAlarmTypes = {};

  static const Duration _predictionDebounceDelay = Duration(seconds: 2);

  List<double> _scalerMean = [
    1011.9789915966387,
    1195.7100840336134,
    2018.2016806722688,
  ];
  List<double> _scalerStd = [
    142.39232840605948,
    218.74225072274777,
    1145.5250169101166,
  ];

  List<String> _labelClasses = ['fire', 'normal', 'smoke'];

  Future<bool> loadModel() async {
    if (_isModelLoaded && _interpreter != null) {
      print('Fire Prediction Service: Model already loaded');
      return true;
    }

    try {
      print('Fire Prediction Service: Loading model from assets...');
      final modelPath = 'assets/models/fire_model.tflite';
      _interpreter = await Interpreter.fromAsset(modelPath);

      print('Fire Prediction Service: Model loaded successfully');
      print('Input tensor count: ${_interpreter!.getInputTensors().length}');
      print('Output tensor count: ${_interpreter!.getOutputTensors().length}');

      for (var i = 0; i < _interpreter!.getInputTensors().length; i++) {
        final inputTensor = _interpreter!.getInputTensors()[i];
        print('Input $i: shape=${inputTensor.shape}, type=${inputTensor.type}');
      }

      for (var i = 0; i < _interpreter!.getOutputTensors().length; i++) {
        final outputTensor = _interpreter!.getOutputTensors()[i];
        print(
          'Output $i: shape=${outputTensor.shape}, type=${outputTensor.type}',
        );
      }

      _isModelLoaded = true;
      return true;
    } catch (e, stackTrace) {
      print('Fire Prediction Service: Error loading model: $e');
      print('Stack trace: $stackTrace');
      _isModelLoaded = false;
      _interpreter = null;
      return false;
    }
  }

  Future<Map<String, double>?> getSensorData(String deviceId) async {
    try {
      final dbRef = FirebaseDatabase.instance.ref();
      final snapshot = await dbRef.child('Devices/$deviceId').get();

      if (!snapshot.exists) {
        print('Fire Prediction Service: Device $deviceId not found in RTDB');
        return null;
      }

      final data = snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) {
        print('Fire Prediction Service: No data for device $deviceId');
        return null;
      }

      final mq2 = _parseDouble(data['MQ2'] ?? data['mq2']);
      final mq9 = _parseDouble(data['MQ9'] ?? data['mq9']);
      final flame = _parseDouble(data['Flame'] ?? data['flame']);

      if (mq2 == null || mq9 == null || flame == null) {
        print(
          'Fire Prediction Service: Missing sensor data for device $deviceId',
        );
        print('Available keys: ${data.keys.toList()}');
        return null;
      }

      return {'mq2': mq2, 'mq9': mq9, 'flame': flame};
    } catch (e, stackTrace) {
      print('Fire Prediction Service: Error fetching sensor data: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  List<double> _scaleSensorData(Map<String, double> sensorData) {
    final mq2 = sensorData['mq2']!;
    final mq9 = sensorData['mq9']!;
    final flame = sensorData['flame']!;

    return [
      (mq2 - _scalerMean[0]) / _scalerStd[0],
      (mq9 - _scalerMean[1]) / _scalerStd[1],
      (flame - _scalerMean[2]) / _scalerStd[2],
    ];
  }

  Future<Map<String, dynamic>?> predict(String deviceId) async {
    if (!_isModelLoaded || _interpreter == null) {
      print('Fire Prediction Service: Model not loaded. Loading now...');
      final loaded = await loadModel();
      if (!loaded) {
        print('Fire Prediction Service: Failed to load model');
        return null;
      }
    }

    final sensorData = await getSensorData(deviceId);
    if (sensorData == null) {
      print('Fire Prediction Service: Could not fetch sensor data');
      return null;
    }

    try {
      final scaledData = _scaleSensorData(sensorData);
      print('Fire Prediction Service: Raw sensor data: $sensorData');
      print('Fire Prediction Service: Scaled data: $scaledData');

      final input = [scaledData];

      final outputTensor = _interpreter!.getOutputTensors()[0];
      final outputShape = outputTensor.shape;
      print('Fire Prediction Service: Output tensor shape: $outputShape');

      final output = _createOutputBuffer(outputShape);

      _interpreter!.run(input, output);
      print('Fire Prediction Service: Model output: $output');

      final probabilities = _extractProbabilities(output, outputShape);

      double maxProb = probabilities[0];
      int predictedIndex = 0;
      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          predictedIndex = i;
        }
      }

      final predictedLabel =
          predictedIndex < _labelClasses.length
              ? _labelClasses[predictedIndex]
              : 'unknown';

      return {
        'label': predictedLabel,
        'confidence': maxProb,
        'probabilities': probabilities,
        'sensorData': sensorData,
      };
    } catch (e, stackTrace) {
      print('Fire Prediction Service: Error during prediction: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<Map<String, dynamic>?> predictWithValues(
    double mq2,
    double mq9,
    double flame,
  ) async {
    if (!_isModelLoaded || _interpreter == null) {
      print('Fire Prediction Service: Model not loaded. Loading now...');
      final loaded = await loadModel();
      if (!loaded) {
        print('Fire Prediction Service: Failed to load model');
        return null;
      }
    }

    try {
      final sensorData = {'mq2': mq2, 'mq9': mq9, 'flame': flame};
      final scaledData = _scaleSensorData(sensorData);
      print('Fire Prediction Service: Raw sensor data: $sensorData');
      print('Fire Prediction Service: Scaled data: $scaledData');

      final input = [scaledData];

      final outputTensor = _interpreter!.getOutputTensors()[0];
      final outputShape = outputTensor.shape;
      print('Fire Prediction Service: Output tensor shape: $outputShape');

      final output = _createOutputBuffer(outputShape);

      _interpreter!.run(input, output);
      print('Fire Prediction Service: Model output: $output');

      final probabilities = _extractProbabilities(output, outputShape);

      double maxProb = probabilities[0];
      int predictedIndex = 0;
      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          predictedIndex = i;
        }
      }

      final predictedLabel =
          predictedIndex < _labelClasses.length
              ? _labelClasses[predictedIndex]
              : 'unknown';

      return {
        'label': predictedLabel,
        'confidence': maxProb,
        'probabilities': probabilities,
        'sensorData': sensorData,
      };
    } catch (e, stackTrace) {
      print('Fire Prediction Service: Error during prediction: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  void updateScalerParams({
    required List<double> mean,
    required List<double> std,
  }) {
    if (mean.length != 3 || std.length != 3) {
      throw ArgumentError('Mean and std must have exactly 3 values');
    }

    _scalerMean = List<double>.from(mean);
    _scalerStd = List<double>.from(std);

    print('Fire Prediction Service: Scaler params updated');
    print('Mean: $_scalerMean');
    print('Std: $_scalerStd');
  }

  void updateLabelClasses(List<String> labels) {
    if (labels.isEmpty) {
      throw ArgumentError('Labels list cannot be empty');
    }

    _labelClasses = List<String>.from(labels);
    print('Fire Prediction Service: Label classes updated');
    print('Labels: $_labelClasses');
  }

  dynamic _createOutputBuffer(List<int> shape) {
    if (shape.isEmpty) {
      return <double>[];
    }

    if (shape.length == 1) {
      return List.generate(shape[0], (index) => 0.0);
    } else if (shape.length == 2) {
      return List.generate(
        shape[0],
        (i) => List.generate(shape[1], (j) => 0.0),
      );
    } else {
      return _createNestedBuffer(shape, 0);
    }
  }

  dynamic _createNestedBuffer(List<int> shape, int index) {
    if (index == shape.length - 1) {
      return List.generate(shape[index], (i) => 0.0);
    } else {
      return List.generate(
        shape[index],
        (i) => _createNestedBuffer(shape, index + 1),
      );
    }
  }

  List<double> _extractProbabilities(dynamic output, List<int> shape) {
    if (output == null) {
      throw ArgumentError('Output cannot be null');
    }

    if (shape.isEmpty) {
      if (output is List<double>) {
        return output;
      }
      throw ArgumentError('Invalid output format for empty shape');
    }

    if (shape.length == 1) {
      if (output is List<double>) {
        return output;
      }
      throw ArgumentError('Expected List<double> for shape $shape');
    } else if (shape.length == 2) {
      if (output is List && output.isNotEmpty) {
        final firstBatch = output[0];
        if (firstBatch is List<double>) {
          return firstBatch;
        } else if (firstBatch is List) {
          return firstBatch.map((e) => (e as num).toDouble()).toList();
        }
      }
      throw ArgumentError('Expected List<List<double>> for shape $shape');
    } else {
      dynamic current = output;
      for (int i = 0; i < shape.length - 1; i++) {
        if (current is List && current.isNotEmpty) {
          current = current[0];
        } else {
          throw ArgumentError('Cannot extract probabilities from shape $shape');
        }
      }

      if (current is List<double>) {
        return current;
      } else if (current is List) {
        return current.map((e) => (e as num).toDouble()).toList();
      }
      throw ArgumentError('Invalid output format for shape $shape');
    }
  }

  void printPrediction(Map<String, dynamic>? result) {
    if (result == null) {
      print('═══════════════════════════════════════════════════════');
      print('🔥 FIRE PREDICTION SERVICE - RESULT');
      print('═══════════════════════════════════════════════════════');
      print('❌ Prediction failed - No result returned');
      print('═══════════════════════════════════════════════════════');
      return;
    }

    final label = result['label'] as String;
    final confidence = result['confidence'] as double;
    final probabilities = result['probabilities'] as List<double>;
    final sensorData = result['sensorData'] as Map<String, double>;

    print('\n═══════════════════════════════════════════════════════');
    print('🔥 FIRE PREDICTION SERVICE - RESULT');
    print('═══════════════════════════════════════════════════════');
    print('📊 SENSOR DATA:');
    print(' MQ2: ${sensorData['mq2']?.toStringAsFixed(2) ?? 'N/A'}');
    print(' MQ9: ${sensorData['mq9']?.toStringAsFixed(2) ?? 'N/A'}');
    print(' Flame: ${sensorData['flame']?.toStringAsFixed(2) ?? 'N/A'}');
    print('');
    print('🎯 PREDICTION:');
    print(' Label: $label');
    print(' Confidence: ${(confidence * 100).toStringAsFixed(2)}%');
    print('');
    print('📈 ALL PROBABILITIES:');
    for (int i = 0; i < probabilities.length; i++) {
      final classLabel =
          i < _labelClasses.length ? _labelClasses[i] : 'Class $i';
      final prob = probabilities[i];
      final percentage = (prob * 100).toStringAsFixed(2);
      final bar = '█' * ((prob * 50).round());
      print(' ${classLabel.padRight(12)}: ${percentage.padLeft(6)}% $bar');
    }
    print('═══════════════════════════════════════════════════════\n');
  }

  Future<void> testPrediction({
    required double mq2,
    required double mq9,
    required double flame,
  }) async {
    print('\n🧪 TESTING FIRE PREDICTION MODEL');
    print('═══════════════════════════════════════════════════════');
    print('Loading model and making prediction...\n');

    // Load model if not already loaded
    if (!_isModelLoaded || _interpreter == null) {
      final loaded = await loadModel();
      if (!loaded) {
        print('❌ Failed to load model');
        return;
      }
    }

    // Make prediction
    final result = await predictWithValues(mq2, mq9, flame);

    // Print results
    printPrediction(result);
  }

  Future<void> testDevicePrediction(String deviceId) async {
    print('\n🧪 TESTING FIRE PREDICTION FOR DEVICE: $deviceId');
    print('═══════════════════════════════════════════════════════');
    print('Loading model and fetching sensor data...\n');

    // Load model if not already loaded
    if (!_isModelLoaded || _interpreter == null) {
      final loaded = await loadModel();
      if (!loaded) {
        print('❌ Failed to load model');
        return;
      }
    }

    final result = await predict(deviceId);

    printPrediction(result);
  }

  Future<void> startRealtimePrediction(String deviceId) async {
    // Stop any existing listener
    stopRealtimePrediction();

    print('\n🔴 STARTING REAL-TIME PREDICTION LISTENER');
    print('═══════════════════════════════════════════════════════');
    print('Device: $deviceId');
    print('Listening to: Devices/$deviceId');
    print('Timestamp: ${DateTime.now()}\n');

    // Load model if not already loaded
    if (!_isModelLoaded || _interpreter == null) {
      print('📦 Loading TensorFlow Lite model...');
      final loaded = await loadModel();
      if (!loaded) {
        print('❌ Failed to load model. Cannot start real-time prediction.');
        print(' Please check if assets/models/fire_model.tflite exists');
        return;
      }
      print('✅ Model loaded successfully\n');
    } else {
      print('✅ Model already loaded\n');
    }

    final dbRef = FirebaseDatabase.instance.ref();

    _lastSensorValues = {'mq2': null, 'mq9': null, 'flame': null};

    _realtimeListener = dbRef
        .child('Devices/$deviceId')
        .onValue
        .listen(
          (event) async {
            print(
              '📡 Real-time Prediction: Data change detected for $deviceId',
            );

            final data = event.snapshot.value as Map<dynamic, dynamic>?;
            if (data == null) {
              print('⚠️ Real-time Prediction: No data for device $deviceId');
              return;
            }

            print(
              '📊 Real-time Prediction: Available keys: ${data.keys.toList()}',
            );

            final mq2 = _parseDouble(data['MQ2'] ?? data['mq2']);
            final mq9 = _parseDouble(data['MQ9'] ?? data['mq9']);
            final flame = _parseDouble(data['Flame'] ?? data['flame']);

            print(
              '🔍 Real-time Prediction: Extracted values - '
              'MQ2: ${mq2?.toStringAsFixed(1) ?? "null"}, '
              'MQ9: ${mq9?.toStringAsFixed(1) ?? "null"}, '
              'Flame: ${flame?.toStringAsFixed(1) ?? "null"}',
            );

            if (mq2 != null) _lastSensorValues['mq2'] = mq2;
            if (mq9 != null) _lastSensorValues['mq9'] = mq9;
            if (flame != null) _lastSensorValues['flame'] = flame;

            final latestMq2 = mq2 ?? _lastSensorValues['mq2'];
            final latestMq9 = mq9 ?? _lastSensorValues['mq9'];
            final latestFlame = flame ?? _lastSensorValues['flame'];

            if (latestMq2 == null || latestMq9 == null || latestFlame == null) {
              print(
                '⏳ Real-time Prediction: Waiting for all sensor data... '
                '(MQ2: ${latestMq2 != null ? latestMq2.toStringAsFixed(1) : "?"}, '
                'MQ9: ${latestMq9 != null ? latestMq9.toStringAsFixed(1) : "?"}, '
                'Flame: ${latestFlame != null ? latestFlame.toStringAsFixed(1) : "?"})',
              );
              return;
            }

            _debounceTimer?.cancel();

            _debounceTimer = Timer(_predictionDebounceDelay, () async {
              try {
                print('\n🔄 Sensor data updated - Running prediction...');
                print(
                  ' MQ2: ${latestMq2.toStringAsFixed(1)}, '
                  'MQ9: ${latestMq9.toStringAsFixed(1)}, '
                  'Flame: ${latestFlame.toStringAsFixed(1)}',
                );

                final result = await predictWithValues(
                  latestMq2,
                  latestMq9,
                  latestFlame,
                );

                printPrediction(result);

                if (result != null) {
                  await _savePredictionToFirestore(deviceId, result);
                }
              } catch (e, stackTrace) {
                print('❌ Error during real-time prediction: $e');
                print('Stack trace: $stackTrace');
              }
            });
          },
          onError: (error) {
            print('❌ Real-time Database listener error: $error');
          },
        );

    _isListening = true;
    print('✅ Real-time prediction listener started!');
    print(
      ' Predictions will be printed automatically when sensor data changes.\n',
    );
  }

  void stopRealtimePrediction([String? deviceId]) {
    if (deviceId != null) {
      try {
        _deviceListeners[deviceId]?.cancel();
      } catch (e) {
        print('Warning: Error cancelling listener for $deviceId: $e');
      }
      _deviceListeners.remove(deviceId);
      print('🛑 Stopped real-time prediction listener for device $deviceId');
    } else {
      if (_realtimeListener != null) {
        try {
          _realtimeListener!.cancel();
        } catch (e) {
          print('Warning: Error cancelling realtime listener: $e');
        }
        _realtimeListener = null;
        print('🛑 Real-time prediction listener stopped');
      }
    }

    _isListening = _deviceListeners.isNotEmpty || _realtimeListener != null;
    _debounceTimer?.cancel();
    _debounceTimer = null;

    _lastSensorValues = {'mq2': null, 'mq9': null, 'flame': null};
  }

  void stopAllRealtimePredictions() {
    for (var entry in _deviceListeners.entries) {
      try {
        entry.value.cancel();
        print('🛑 Stopped real-time prediction listener for device ${entry.key}');
      } catch (e) {
        print('Warning: Error cancelling listener for ${entry.key}: $e');
      }
    }
    _deviceListeners.clear();

    if (_realtimeListener != null) {
      try {
        _realtimeListener!.cancel();
      } catch (e) {
        print('Warning: Error cancelling realtime listener: $e');
      }
      _realtimeListener = null;
    }

    _isListening = false;
    _debounceTimer?.cancel();
    _debounceTimer = null;

    _lastSensorValues = {'mq2': null, 'mq9': null, 'flame': null};
    print('🛑 All real-time prediction listeners stopped');
  }

  Future<void> _startRealtimePredictionForDevice(String deviceId) async {
    if (_deviceListeners.containsKey(deviceId)) {
      print(
        'Fire Prediction Service: Already listening to device $deviceId, skipping',
      );
      return;
    }

    final dbRef = FirebaseDatabase.instance.ref();

    _lastSensorValues = {'mq2': null, 'mq9': null, 'flame': null};

    final listener = dbRef
        .child('Devices/$deviceId')
        .onValue
        .listen(
          (event) async {
            final data = event.snapshot.value as Map<dynamic, dynamic>?;
            if (data == null) {
              return;
            }

            final mq2 = _parseDouble(data['MQ2'] ?? data['mq2']);
            final mq9 = _parseDouble(data['MQ9'] ?? data['mq9']);
            final flame = _parseDouble(data['Flame'] ?? data['flame']);

            if (mq2 != null) _lastSensorValues['mq2'] = mq2;
            if (mq9 != null) _lastSensorValues['mq9'] = mq9;
            if (flame != null) _lastSensorValues['flame'] = flame;

            final latestMq2 = mq2 ?? _lastSensorValues['mq2'];
            final latestMq9 = mq9 ?? _lastSensorValues['mq9'];
            final latestFlame = flame ?? _lastSensorValues['flame'];

            if (latestMq2 == null || latestMq9 == null || latestFlame == null) {
              return;
            }

            _debounceTimer?.cancel();

            _debounceTimer = Timer(_predictionDebounceDelay, () async {
              try {
                final result = await predictWithValues(
                  latestMq2,
                  latestMq9,
                  latestFlame,
                );

                printPrediction(result);

                if (result != null) {
                  await _savePredictionToFirestore(deviceId, result);
                }
              } catch (e, stackTrace) {
                print('❌ Error during real-time prediction for $deviceId: $e');
                print('Stack trace: $stackTrace');
              }
            });
          },
          onError: (error) {
            print('❌ Real-time Database listener error for $deviceId: $error');
          },
        );

    _deviceListeners[deviceId] = listener;
    print('✅ Started real-time prediction listener for device $deviceId');
  }

  Future<void> _savePredictionToFirestore(
    String deviceId,
    Map<String, dynamic> predictionResult,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ Cannot save prediction: User not logged in');
        return;
      }

      final predictedLabel = predictionResult['label'] as String;
      final confidence = predictionResult['confidence'] as double;

      final previousAlarmType = _previousAlarmTypes[deviceId];

      final deviceDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId);

      final deviceDoc = await deviceDocRef.get();
      final deviceData = deviceDoc.data();
      final deviceName = deviceData?['name'] as String? ?? 'Your device';
      final deviceAddress = deviceData?['address'] as String?;

      await deviceDocRef.update({
        'alarmType': predictedLabel,
        'lastPrediction': {
          'label': predictedLabel,
          'confidence': confidence,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'lastPredictionAt': FieldValue.serverTimestamp(),
      });

      // Update previous alarmType
      _previousAlarmTypes[deviceId] = predictedLabel;

      // Update RTDB Alarm field based on alarmType
      await _updateRTDBAlarm(deviceId, predictedLabel, previousAlarmType);

      // Send notification if alarmType changed to "smoke"
      if (predictedLabel == 'smoke' && previousAlarmType != 'smoke') {
        await _sendSmokeNotification(deviceId, deviceName, deviceAddress);
      }

      print(
        '✅ Updated alarmType in Firestore for device $deviceId: $predictedLabel '
        '(${(confidence * 100).toStringAsFixed(1)}% confidence)',
      );
    } catch (e, stackTrace) {
      print('❌ Error saving prediction to Firestore: $e');
      print('Stack trace: $stackTrace');
      // Don't throw - we don't want save errors to crash the prediction flow
    }
  }

  Future<void> startListeningToAllUserDevices() async {
    // Stop any existing listeners first
    stopAllRealtimePredictions();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print(
        'Fire Prediction Service: No user logged in, cannot start listening',
      );
      return;
    }

    final userId = user.uid;
    print(
      'Fire Prediction Service: Starting to listen to all devices for user $userId',
    );

    // Load model if not already loaded
    if (!_isModelLoaded || _interpreter == null) {
      print('Fire Prediction Service: Loading model...');
      final loaded = await loadModel();
      if (!loaded) {
        print(
          'Fire Prediction Service: Failed to load model. Cannot start listening.',
        );
        return;
      }
    }

    // Fetch all devices from the current user's Firestore collection
    // Path: users/{userId}/devices - ensures we only get this user's devices
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('devices')
              .get();

      print(
        'Fire Prediction Service: Found ${snapshot.docs.length} device(s) for user $userId',
      );

      if (snapshot.docs.isEmpty) {
        print(
          'Fire Prediction Service: No devices found for user $userId. Predictions will start when devices are added.',
        );
        return;
      }

      // Start listening to each device that belongs to this user
      for (var doc in snapshot.docs) {
        final deviceData = doc.data();
        final deviceId = deviceData['deviceId'] as String?;

        if (deviceId != null) {
          // Initialize previous alarmType to current value to avoid false notifications
          final currentAlarmType = deviceData['alarmType'] as String?;
          _previousAlarmTypes[deviceId] = currentAlarmType;

          // Sync RTDB Alarm field if device already has alarmType="fire"
          if (currentAlarmType != null && currentAlarmType == 'fire') {
            await _updateRTDBAlarm(deviceId, currentAlarmType, null);
          }

          print(
            'Fire Prediction Service: Starting prediction listener for user device $deviceId (user: $userId)',
          );
          await _startRealtimePredictionForDevice(deviceId);
        } else {
          print(
            'Fire Prediction Service: Device document ${doc.id} has no deviceId, skipping',
          );
        }
      }

      _isListening = _deviceListeners.isNotEmpty;
      if (_isListening) {
        print(
          '✅ Fire Prediction Service: Started listening to ${_deviceListeners.length} device(s) for user $userId',
        );
      }
    } catch (e, stackTrace) {
      print('Fire Prediction Service: Error fetching user devices: $e');
      print('Stack trace: $stackTrace');
      // Don't let Firestore errors crash the app
    }
  }

  /// Update RTDB Alarm field based on alarmType
  /// Sets Alarm to true when alarmType is "fire", false otherwise
  Future<void> _updateRTDBAlarm(
    String deviceId,
    String currentAlarmType,
    String? previousAlarmType,
  ) async {
    try {
      final dbRef = FirebaseDatabase.instance.ref();
      final alarmPath = 'Devices/$deviceId/Alarm';

      // If alarmType is "fire", set Alarm to true
      if (currentAlarmType == 'fire') {
        // Only update if it wasn't already fire (avoid unnecessary writes)
        if (previousAlarmType != 'fire') {
          await dbRef
              .child(alarmPath)
              .set(true)
              .timeout(const Duration(seconds: 5));
          print(
            '✅ Updated RTDB Alarm to true for device $deviceId (fire detected)',
          );
        }
      } else {
        // If alarmType changed from "fire" to something else, set Alarm to false
        if (previousAlarmType == 'fire') {
          await dbRef
              .child(alarmPath)
              .set(false)
              .timeout(const Duration(seconds: 5));
          print(
            '✅ Updated RTDB Alarm to false for device $deviceId '
            '(alarmType changed from fire to $currentAlarmType)',
          );
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error updating RTDB Alarm: $e');
      print('Stack trace: $stackTrace');
      // Don't throw - RTDB update errors shouldn't crash the prediction flow
    }
  }

  /// Send smoke detection notification to the user
  Future<void> _sendSmokeNotification(
    String deviceId,
    String deviceName,
    String? deviceAddress,
  ) async {
    try {
      // Build notification message with device location if available
      String notificationBody;
      if (deviceAddress != null && deviceAddress.isNotEmpty) {
        notificationBody =
            'Smoke or gas leak detected by $deviceName located at $deviceAddress. '
            'Please check the sensor immediately to ensure safety.';
      } else {
        notificationBody =
            'Smoke or gas leak detected by $deviceName. '
            'Please check the sensor immediately to ensure safety.';
      }

      await NotificationService().showNotification(
        title: 'Smoke/Gas Detection Alert',
        body: notificationBody,
        deviceId: deviceId,
      );

      print(
        '✅ Smoke detection notification sent for device $deviceId ($deviceName)',
      );
    } catch (e, stackTrace) {
      print('❌ Error sending smoke notification: $e');
      print('Stack trace: $stackTrace');
      // Don't throw - notification errors shouldn't crash the prediction flow
    }
  }

  /// Check if currently listening to real-time predictions
  bool get isListening => _isListening;

  /// Dispose resources
  void dispose() {
    stopAllRealtimePredictions();
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
    _previousAlarmTypes.clear();
  }
}
