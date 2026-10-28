#!/usr/bin/env python3
"""下载官方演示权重，仅用于本机接入验证；不上传业务数据，不发布权重。"""
import hashlib
import json
import urllib.request
from pathlib import Path
import onnx

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'example/assets/models'
DEST.mkdir(parents=True, exist_ok=True)
LABELS = ['person','bicycle','car','motorcycle','airplane','bus','train','truck','boat','traffic light','fire hydrant','stop sign','parking meter','bench','bird','cat','dog','horse','sheep','cow','elephant','bear','zebra','giraffe','backpack','umbrella','handbag','tie','suitcase','frisbee','skis','snowboard','sports ball','kite','baseball bat','baseball glove','skateboard','surfboard','tennis racket','bottle','wine glass','cup','fork','knife','spoon','bowl','banana','apple','sandwich','orange','broccoli','carrot','hot dog','pizza','donut','cake','chair','couch','potted plant','bed','dining table','toilet','tv','laptop','mouse','remote','keyboard','cell phone','microwave','oven','toaster','sink','refrigerator','book','clock','vase','scissors','teddy bear','hair drier','toothbrush']
MODELS = {
    's': '09fc88131be8ad224f13739a5cf8fc838600d76a77539af7f0400fa90506c5f3',
    'xs': '3b8e7687122d70b1615734827b19f28e24cde83cb59b4d27845a3566da4b8510',
}
for variant, expected in MODELS.items():
    url = f'https://paddledet.bj.bcebos.com/deploy/third_engine/picodet_{variant}_320_lcnet_postprocessed.onnx'
    raw = urllib.request.urlopen(url, timeout=90).read()
    if hashlib.sha256(raw).hexdigest() != expected:
        raise RuntimeError(f'{variant}: 上游权重变化，停止并重新核对来源')
    model = onnx.load_from_string(raw)
    # 官方旧导出把常量列在输入中，删除冗余声明，让运行时正确折叠常量。
    initializers = {i.name for i in model.graph.initializer}
    for value in list(model.graph.input):
        if value.name in initializers: model.graph.input.remove(value)
    model.graph.input[0].type.tensor_type.shape.dim[0].dim_value = 1
    # 旧官方导出的 bbox_num 是候选锚点数 2125，而实际 NMS 输出最多 100 行。
    # 从真实输出张量维度计算数量，避免业务端截断或接受错误的张量协议。
    boxes = 'multiclass_nms3_0.tmp_0'
    count = 'delivery_bbox_count'
    model.graph.output[0].type.tensor_type.shape.dim[0].ClearField('dim_value')
    model.graph.output[0].type.tensor_type.shape.dim[0].dim_param = 'detections'
    for value in list(model.graph.value_info):
        if value.name == boxes: model.graph.value_info.remove(value)
    model.graph.initializer.append(onnx.helper.make_tensor('delivery_count_axis', onnx.TensorProto.INT64, [1], [0]))
    model.graph.node.extend([
        onnx.helper.make_node('Shape', [boxes], ['delivery_boxes_shape']),
        onnx.helper.make_node('Gather', ['delivery_boxes_shape', 'delivery_count_axis'], ['delivery_count_int64'], axis=0),
        onnx.helper.make_node('Cast', ['delivery_count_int64'], [count], to=onnx.TensorProto.INT32),
    ])
    model.graph.output.pop()
    model.graph.output.append(onnx.helper.make_tensor_value_info(count, onnx.TensorProto.INT32, [1]))
    onnx.checker.check_model(model)
    output = DEST / f'picodet_{variant}_320.onnx'
    onnx.save(model, output)
    manifest = {
        'name': f'PP-PicoDet-{variant.upper()} COCO 320 / integration baseline',
        'inputSize': 320, 'labels': LABELS,
        'boxesOutput': 'multiclass_nms3_0.tmp_0', 'countOutput': 'delivery_bbox_count',
        'inputLayout': 'NCHW float32 RGB', 'resize': 'stretch',
        'mean': [0.485,0.456,0.406], 'std': [0.229,0.224,0.225],
        'upstreamUrl': url, 'upstreamSha256': expected,
        'sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
        'upstreamRepositoryLicense': 'Apache-2.0',
        'weightsLicenseStatus': 'No separate checkpoint license statement verified; do not treat this as production redistribution clearance.',
        'parcelSpecialist': False,
        'modifications': ['remove redundant initializer inputs', 'fix batch=1', 'derive bbox count from real output shape'],
        'limitations': ['COCO has no delivery carton, plastic delivery bag, beverage case or shrink-wrapped multipack class.',
            'For internal integration evaluation; weights are excluded from the public source distribution.'],
    }
    output.with_suffix('.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n')
    print(f'{variant}: {output.stat().st_size:,} bytes, sha256={manifest["sha256"]}')
