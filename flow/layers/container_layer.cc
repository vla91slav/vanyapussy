// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/flow/layers/container_layer.h"

#include <optional>

namespace flutter {

ContainerLayer::ContainerLayer() {}

#ifdef FLUTTER_ENABLE_DIFF_CONTEXT

void ContainerLayer::Diff(DiffContext* context, const Layer* old_layer) {
  auto old_container = static_cast<const ContainerLayer*>(old_layer);
  DiffContext::AutoSubtreeRestore subtree(context);
  DiffChildren(context, old_container);
  context->SetLayerPaintRegion(this, context->CurrentSubtreeRegion());
}

void ContainerLayer::PreservePaintRegion(DiffContext* context) {
  Layer::PreservePaintRegion(context);
  for (auto& layer : layers_) {
    layer->PreservePaintRegion(context);
  }
}

void ContainerLayer::DiffChildren(DiffContext* context,
                                  const ContainerLayer* old_layer) {
  if (context->IsSubtreeDirty()) {
    for (auto& layer : layers_) {
      layer->Diff(context, nullptr);
    }
    return;
  }
  FML_DCHECK(old_layer);

  const auto& prev_layers = old_layer->layers_;

  // first mismatched element
  int new_children_top = 0;
  int old_children_top = 0;

  // last mismatched element
  int new_children_bottom = layers_.size() - 1;
  int old_children_bottom = prev_layers.size() - 1;

  while ((old_children_top <= old_children_bottom) &&
         (new_children_top <= new_children_bottom)) {
    if (!layers_[new_children_top]->IsReplacing(
            context, prev_layers[old_children_top].get())) {
      break;
    }
    ++new_children_top;
    ++old_children_top;
  }

  while ((old_children_top <= old_children_bottom) &&
         (new_children_top <= new_children_bottom)) {
    if (!layers_[new_children_bottom]->IsReplacing(
            context, prev_layers[old_children_bottom].get())) {
      break;
    }
    --new_children_bottom;
    --old_children_bottom;
  }

  // old layers that don't match
  for (int i = old_children_top; i <= old_children_bottom; ++i) {
    auto layer = prev_layers[i];
    context->AddDamage(context->GetOldLayerPaintRegion(layer.get()));
  }

  for (int i = 0; i < static_cast<int>(layers_.size()); ++i) {
    if (i < new_children_top || i > new_children_bottom) {
      int i_prev =
          i < new_children_top ? i : prev_layers.size() - (layers_.size() - i);
      auto layer = layers_[i];
      auto prev_layer = prev_layers[i_prev];
      auto paint_region = context->GetOldLayerPaintRegion(prev_layer.get());
      if (layer == prev_layer && !paint_region.has_readback()) {
        // for retained layers, stop processing the subtree and add existing
        // region; We know current subtree is not dirty (every ancestor up to
        // here matches) so the retained subtree will render identically to
        // previous frame; We can only do this if there is no readback in the
        // subtree. Layers that do readback must be able to register readback
        // inside Diff
        context->AddExistingPaintRegion(paint_region);

        // While we don't need to diff retained layers, we still need to
        // associate their paint region with current layer tree so that we can
        // retrieve it in next frame diff
        layer->PreservePaintRegion(context);
      } else {
        layer->Diff(context, prev_layer.get());
      }
    } else {
      DiffContext::AutoSubtreeRestore subtree(context);
      context->MarkSubtreeDirty();
      auto layer = layers_[i];
      layer->Diff(context, nullptr);
    }
  }
}

#endif  // FLUTTER_ENABLE_DIFF_CONTEXT

void ContainerLayer::Add(std::shared_ptr<Layer> layer) {
  layers_.emplace_back(std::move(layer));
}

void ContainerLayer::Preroll(PrerollContext* context, const SkMatrix& matrix) {
  TRACE_EVENT0("flutter", "ContainerLayer::Preroll");

  SkRect child_paint_bounds = SkRect::MakeEmpty();
  PrerollChildren(context, matrix, &child_paint_bounds);
  set_paint_bounds(child_paint_bounds);
}

void ContainerLayer::Paint(PaintContext& context) const {
  FML_DCHECK(needs_painting(context));

  PaintChildren(context);
}

void ContainerLayer::PrerollChildren(PrerollContext* context,
                                     const SkMatrix& child_matrix,
                                     SkRect* child_paint_bounds) {
  // Platform views have no children, so context->has_platform_view should
  // always be false.
  FML_DCHECK(!context->has_platform_view);
  bool child_has_platform_view = false;
  bool child_has_texture_layer = false;
  for (auto& layer : layers_) {
    // Reset context->has_platform_view to false so that layers aren't treated
    // as if they have a platform view based on one being previously found in a
    // sibling tree.
    context->has_platform_view = false;

    layer->Preroll(context, child_matrix);
    child_paint_bounds->join(layer->paint_bounds());

    child_has_platform_view =
        child_has_platform_view || context->has_platform_view;
    child_has_texture_layer =
        child_has_texture_layer || context->has_texture_layer;
  }

  context->has_platform_view = child_has_platform_view;
  context->has_texture_layer = child_has_texture_layer;
  set_subtree_has_platform_view(child_has_platform_view);
}

void ContainerLayer::PaintChildren(PaintContext& context) const {
  // We can no longer call FML_DCHECK here on the needs_painting(context)
  // condition as that test is only valid for the PaintContext that
  // is initially handed to a layer's Paint() method. By the time the
  // layer calls PaintChildren(), though, it may have modified the
  // PaintContext so the test doesn't work in this "context".

  // Intentionally not tracing here as there should be no self-time
  // and the trace event on this common function has a small overhead.
  for (auto& layer : layers_) {
    if (layer->needs_painting(context)) {
      layer->Paint(context);
    }
  }
}

void ContainerLayer::TryToPrepareRasterCache(PrerollContext* context,
                                             Layer* layer,
                                             const SkMatrix& matrix) {
  if (!context->has_platform_view && !context->has_texture_layer &&
      context->raster_cache &&
      SkRect::Intersects(context->cull_rect, layer->paint_bounds())) {
    context->raster_cache->Prepare(context, layer, matrix);
  }
}

MergedContainerLayer::MergedContainerLayer() {
  // Ensure the layer has only one direct child.
  //
  // Any children will actually be added as children of this empty
  // ContainerLayer which can be accessed via ::GetContainerLayer().
  // If only one child is ever added to this layer then that child
  // will become the layer returned from ::GetCacheableChild().
  // If multiple child layers are added, then this implicit container
  // child becomes the cacheable child, but at the potential cost of
  // not being as stable in the raster cache from frame to frame.
  ContainerLayer::Add(std::make_shared<ContainerLayer>());
}

#ifdef FLUTTER_ENABLE_DIFF_CONTEXT
void MergedContainerLayer::DiffChildren(DiffContext* context,
                                        const ContainerLayer* old_layer) {
  if (context->IsSubtreeDirty()) {
    GetChildContainer()->Diff(context, nullptr);
    return;
  }
  FML_DCHECK(old_layer);

  // For MergedContainerLayer we want to diff children of ChildContainer
  // instead of the ChildContainer itself. This works around the fact
  // that ChildContainerLayer is ephemeral and its original_layer_id_ is always
  // different.
  auto layer = static_cast<const MergedContainerLayer*>(old_layer);
  GetChildContainer()->DiffChildren(context, layer->GetChildContainer());
}
#endif

void MergedContainerLayer::Add(std::shared_ptr<Layer> layer) {
  GetChildContainer()->Add(std::move(layer));
}

ContainerLayer* MergedContainerLayer::GetChildContainer() const {
  FML_DCHECK(layers().size() == 1);

  return static_cast<ContainerLayer*>(layers()[0].get());
}

Layer* MergedContainerLayer::GetCacheableChild() const {
  ContainerLayer* child_container = GetChildContainer();
  if (child_container->layers().size() == 1) {
    return child_container->layers()[0].get();
  }

  return child_container;
}

}  // namespace flutter
