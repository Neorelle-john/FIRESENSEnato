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

  // Per-device debounce timers to prevent interference between devices
  Map<String, Timer> _deviceDebounceTimers = {};

  // Per-device last sensor values to track each device independently
  Map<String, Map<String, double?>> _deviceLastSensorValues = {};

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

  /// Analyzes which sensor(s) contributed most to the fire prediction
  /// Returns a map with contribution scores and analysis for each sensor
  /// Includes comprehensive error handling to prevent crashes
  Map<String, dynamic>? _analyzeSensorContributions(
    Map<String, double> sensorData,
    String predictedLabel,
  ) {
    try {
      // Validate input data
      if (sensorData.isEmpty) {
        print('⚠️ Sensor analysis: Empty sensor data provided');
        return null;
      }

      final mq2 = sensorData['mq2'];
      final mq9 = sensorData['mq9'];
      final flame = sensorData['flame'];

      // Check for null or invalid values
      if (mq2 == null || mq9 == null || flame == null) {
        print('⚠️ Sensor analysis: Missing sensor values');
        return null;
      }

      // Check for NaN or infinite values
      if (mq2.isNaN || mq2.isInfinite ||
          mq9.isNaN || mq9.isInfinite ||
          flame.isNaN || flame.isInfinite) {
        print('⚠️ Sensor analysis: Invalid sensor values (NaN or Infinite)');
        return null;
      }

      // Validate scaler parameters
      if (_scalerMean.length != 3 || _scalerStd.length != 3) {
        print('⚠️ Sensor analysis: Invalid scaler parameters');
        return null;
      }

      // Check for zero standard deviation (would cause division by zero)
      if (_scalerStd[0] == 0 || _scalerStd[1] == 0 || _scalerStd[2] == 0) {
        print('⚠️ Sensor analysis: Zero standard deviation detected');
        return null;
      }

      // Normal/baseline values (using scaler means as reference)
      final normalValues = {
        'mq2': _scalerMean[0],   // ~1012
        'mq9': _scalerMean[1],   // ~1196
        'flame': _scalerMean[2], // ~2018
      };

      // Calculate scaled data (deviation in standard deviations)
      List<double> scaledData;
      try {
        scaledData = _scaleSensorData(sensorData);
      } catch (e) {
        print('⚠️ Sensor analysis: Error scaling sensor data: $e');
        return null;
      }

      // Calculate absolute deviations from normal (in standard deviations)
      final deviations = {
        'mq2': scaledData[0].abs(),
        'mq9': scaledData[1].abs(),
        'flame': scaledData[2].abs(),
      };

      // Calculate percentage deviation from normal (with safety checks)
      final percentageDeviations = <String, double>{};
      try {
        final mq2Normal = normalValues['mq2']!;
        final mq9Normal = normalValues['mq9']!;
        final flameNormal = normalValues['flame']!;

        if (mq2Normal != 0) {
          percentageDeviations['mq2'] =
              ((mq2 - mq2Normal) / mq2Normal * 100).abs();
        } else {
          percentageDeviations['mq2'] = 0.0;
        }

        if (mq9Normal != 0) {
          percentageDeviations['mq9'] =
              ((mq9 - mq9Normal) / mq9Normal * 100).abs();
        } else {
          percentageDeviations['mq9'] = 0.0;
        }

        if (flameNormal != 0) {
          percentageDeviations['flame'] =
              ((flame - flameNormal) / flameNormal * 100).abs();
        } else {
          percentageDeviations['flame'] = 0.0;
        }
      } catch (e) {
        print('⚠️ Sensor analysis: Error calculating percentage deviations: $e');
        percentageDeviations['mq2'] = 0.0;
        percentageDeviations['mq9'] = 0.0;
        percentageDeviations['flame'] = 0.0;
      }

      // Calculate contribution scores (normalized 0-100)
      final totalDeviation = deviations.values.fold(0.0, (a, b) => a + b);
      final contributions = <String, double>{};

      if (totalDeviation > 0 && !totalDeviation.isNaN && !totalDeviation.isInfinite) {
        contributions['mq2'] = (deviations['mq2']! / totalDeviation * 100)
            .clamp(0.0, 100.0);
        contributions['mq9'] = (deviations['mq9']! / totalDeviation * 100)
            .clamp(0.0, 100.0);
        contributions['flame'] = (deviations['flame']! / totalDeviation * 100)
            .clamp(0.0, 100.0);
      } else {
        // If total deviation is zero or invalid, distribute equally
        contributions['mq2'] = 33.33;
        contributions['mq9'] = 33.33;
        contributions['flame'] = 33.34;
      }

      // Determine which sensors are abnormal (deviation > 2 standard deviations)
      const threshold = 2.0; // 2 standard deviations
      final abnormalSensors = <String>[];
      if (deviations['mq2']! > threshold && !deviations['mq2']!.isNaN) {
        abnormalSensors.add('MQ2');
      }
      if (deviations['mq9']! > threshold && !deviations['mq9']!.isNaN) {
        abnormalSensors.add('MQ9');
      }
      if (deviations['flame']! > threshold && !deviations['flame']!.isNaN) {
        abnormalSensors.add('Flame');
      }

      // Find primary trigger (sensor with highest contribution)
      String? primaryTrigger;
      double maxContribution = 0;
      contributions.forEach((sensor, contribution) {
        if (contribution > maxContribution && !contribution.isNaN) {
          maxContribution = contribution;
          primaryTrigger = sensor.toUpperCase();
        }
      });

      // Generate human-readable analysis
      String analysis = '';
      try {
        if (predictedLabel == 'fire') {
          if (abnormalSensors.isEmpty) {
            analysis =
                'All sensors within normal range, but combined readings indicate fire risk.';
          } else if (abnormalSensors.length == 1) {
            final sensorKey = abnormalSensors[0].toLowerCase();
            final deviation = percentageDeviations[sensorKey] ?? 0.0;
            analysis =
                '${abnormalSensors[0]} sensor reading is significantly elevated '
                '(${deviation.toStringAsFixed(1)}% above normal), indicating potential fire.';
          } else {
            analysis =
                'Multiple sensors showing abnormal readings: ${abnormalSensors.join(', ')}. '
                'Primary trigger: $primaryTrigger (${maxContribution.toStringAsFixed(1)}% contribution).';
          }
        } else if (predictedLabel == 'smoke') {
          if (abnormalSensors.contains('MQ2') || abnormalSensors.contains('MQ9')) {
            analysis =
                'Gas sensors (MQ2/MQ9) detecting elevated levels, indicating smoke or gas leak.';
          } else {
            analysis = 'Smoke detected based on sensor pattern analysis.';
          }
        } else {
          analysis = 'All sensors reading within normal parameters.';
        }
      } catch (e) {
        print('⚠️ Sensor analysis: Error generating analysis text: $e');
        analysis = 'Sensor analysis completed.';
      }

      // Format and return results
      return {
        'primaryTrigger': primaryTrigger ?? 'Unknown',
        'contributions': {
          'mq2': contributions['mq2']!.toStringAsFixed(1),
          'mq9': contributions['mq9']!.toStringAsFixed(1),
          'flame': contributions['flame']!.toStringAsFixed(1),
        },
        'deviations': {
          'mq2': deviations['mq2']!.toStringAsFixed(2),
          'mq9': deviations['mq9']!.toStringAsFixed(2),
          'flame': deviations['flame']!.toStringAsFixed(2),
        },
        'percentageDeviations': {
          'mq2': percentageDeviations['mq2']!.toStringAsFixed(1),
          'mq9': percentageDeviations['mq9']!.toStringAsFixed(1),
          'flame': percentageDeviations['flame']!.toStringAsFixed(1),
        },
        'abnormalSensors': abnormalSensors,
        'analysis': analysis,
      };
    } catch (e, stackTrace) {
      print('❌ Sensor analysis: Unexpected error: $e');
      print('Stack trace: $stackTrace');
      // Return null instead of throwing to prevent breaking the prediction flow
      return null;
    }
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

      // Analyze sensor contributions
      final sensorAnalysis = _analyzeSensorContributions(sensorData, predictedLabel);

      return {
        'label': predictedLabel,
        'confidence': maxProb,
        'probabilities': probabilities,
        'sensorData': sensorData,
        if (sensorAnalysis != null) 'sensorAnalysis': sensorAnalysis,
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

      // Analyze sensor contributions
      final sensorAnalysis = _analyzeSensorContributions(sensorData, predictedLabel);

      return {
        'label': predictedLabel,
        'confidence': maxProb,
        'probabilities': probabilities,
        'sensorData': sensorData,
        if (sensorAnalysis != null) 'sensorAnalysis': sensorAnalysis,
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

    // Display sensor contribution analysis if available
    if (result.containsKey('sensorAnalysis') && result['sensorAnalysis'] != null) {
      try {
        final analysis = result['sensorAnalysis'] as Map<String, dynamic>;
        print('═══════════════════════════════════════════════════════');
        print('🔍 SENSOR CONTRIBUTION ANALYSIS:');
        print(' Primary Trigger: ${analysis['primaryTrigger'] ?? 'N/A'}');
        print('');
        print(' Contribution Scores:');
        if (analysis.containsKey('contributions')) {
          final contributions = analysis['contributions'] as Map<String, dynamic>;
          contributions.forEach((sensor, score) {
            print('  ${sensor.toUpperCase().padRight(6)}: ${score.toString().padLeft(6)}%');
          });
        }
        print('');
        print(' Deviation from Normal:');
        if (analysis.containsKey('percentageDeviations')) {
          final deviations = analysis['percentageDeviations'] as Map<String, dynamic>;
          deviations.forEach((sensor, deviation) {
            print('  ${sensor.toUpperCase().padRight(6)}: ${deviation.toString().padLeft(6)}%');
          });
        }
        print('');
        if (analysis.containsKey('abnormalSensors')) {
          final abnormalSensors = analysis['abnormalSensors'] as List<dynamic>;
          if (abnormalSensors.isNotEmpty) {
            print(' Abnormal Sensors: ${abnormalSensors.join(', ')}');
            print('');
          }
        }
        print(' Analysis: ${analysis['analysis'] ?? 'N/A'}');
        print('═══════════════════════════════════════════════════════');
      } catch (e) {
        print('⚠️ Error displaying sensor analysis: $e');
      }
    }
    print('\n');
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

      // Cancel per-device debounce timer
      _deviceDebounceTimers[deviceId]?.cancel();
      _deviceDebounceTimers.remove(deviceId);

      // Remove per-device sensor values
      _deviceLastSensorValues.remove(deviceId);

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

    // Cancel all device debounce timers
    for (var timer in _deviceDebounceTimers.values) {
      timer.cancel();
    }
    _deviceDebounceTimers.clear();
    _deviceLastSensorValues.clear();

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

    // Cancel all device debounce timers
    for (var timer in _deviceDebounceTimers.values) {
      timer.cancel();
    }
    _deviceDebounceTimers.clear();
    _deviceLastSensorValues.clear();

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

    // Initialize per-device sensor values
    _deviceLastSensorValues[deviceId] = {'mq2': null, 'mq9': null, 'flame': null};

    // Make initial prediction on existing data for immediate response
    try {
      print('Fire Prediction Service: Making initial prediction for $deviceId...');
      final initialData = await getSensorData(deviceId);
      if (initialData != null) {
        print(
          'Fire Prediction Service: Initial sensor data found for $deviceId - '
          'MQ2: ${initialData['mq2']?.toStringAsFixed(1)}, '
          'MQ9: ${initialData['mq9']?.toStringAsFixed(1)}, '
          'Flame: ${initialData['flame']?.toStringAsFixed(1)}',
        );
        final initialResult = await predictWithValues(
          initialData['mq2']!,
          initialData['mq9']!,
          initialData['flame']!,
        );
        if (initialResult != null) {
          printPrediction(initialResult);
          await _savePredictionToFirestore(deviceId, initialResult);
        }
      } else {
        print('Fire Prediction Service: No initial sensor data for $deviceId');
      }
    } catch (e) {
      print('Fire Prediction Service: Error in initial prediction for $deviceId: $e');
    }

    final listener = dbRef
        .child('Devices/$deviceId')
        .onValue
        .listen(
          (event) async {
            print('📡 Real-time Prediction: Data change detected for $deviceId');

            final data = event.snapshot.value as Map<dynamic, dynamic>?;
            if (data == null) {
              print('⚠️ Real-time Prediction: No data for device $deviceId');
              return;
            }

            print('📊 Real-time Prediction: Available keys: ${data.keys.toList()}');

            final mq2 = _parseDouble(data['MQ2'] ?? data['mq2']);
            final mq9 = _parseDouble(data['MQ9'] ?? data['mq9']);
            final flame = _parseDouble(data['Flame'] ?? data['flame']);

            print(
              '🔍 Real-time Prediction: Extracted values for $deviceId - '
              'MQ2: ${mq2?.toStringAsFixed(1) ?? "null"}, '
              'MQ9: ${mq9?.toStringAsFixed(1) ?? "null"}, '
              'Flame: ${flame?.toStringAsFixed(1) ?? "null"}',
            );

            // Update per-device last sensor values
            final deviceLastValues = _deviceLastSensorValues[deviceId] ??
                {'mq2': null, 'mq9': null, 'flame': null};

            if (mq2 != null) deviceLastValues['mq2'] = mq2;
            if (mq9 != null) deviceLastValues['mq9'] = mq9;
            if (flame != null) deviceLastValues['flame'] = flame;

            _deviceLastSensorValues[deviceId] = deviceLastValues;

            final latestMq2 = mq2 ?? deviceLastValues['mq2'];
            final latestMq9 = mq9 ?? deviceLastValues['mq9'];
            final latestFlame = flame ?? deviceLastValues['flame'];

            if (latestMq2 == null || latestMq9 == null || latestFlame == null) {
              print(
                '⏳ Real-time Prediction: Waiting for all sensor data for $deviceId... '
                '(MQ2: ${latestMq2 != null ? latestMq2.toStringAsFixed(1) : "?"}, '
                'MQ9: ${latestMq9 != null ? latestMq9.toStringAsFixed(1) : "?"}, '
                'Flame: ${latestFlame != null ? latestFlame.toStringAsFixed(1) : "?"})',
              );
              return;
            }

            // Cancel this device's debounce timer (per-device to prevent interference)
            _deviceDebounceTimers[deviceId]?.cancel();

            // Use per-device debounce timer
            _deviceDebounceTimers[deviceId] = Timer(_predictionDebounceDelay, () async {
              try {
                print('\n🔄 Sensor data updated for $deviceId - Running prediction...');
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

      // Prepare prediction data with sensor analysis if available
      final predictionData = <String, dynamic>{
        'label': predictedLabel,
        'confidence': confidence,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Add sensor analysis if available
      if (predictionResult.containsKey('sensorAnalysis') &&
          predictionResult['sensorAnalysis'] != null) {
        predictionData['sensorAnalysis'] = predictionResult['sensorAnalysis'];
      }

      await deviceDocRef.update({
        'alarmType': predictedLabel,
        'lastPrediction': predictionData,
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
