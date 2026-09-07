/** Branching story + skill-check engine. */
export class StoryEngine {
  constructor(story, gameState) {
    this.story = story;
    this.state = gameState;
  }

  node(id = this.state.campaignNode) {
    return this.story.nodes[id];
  }

  availableChoices(node = this.node()) {
    if (!node?.choices) return [];
    return node.choices.filter((c) => {
      if (c.requireFlag && !this.state.hasFlag(c.requireFlag)) return false;
      return true;
    });
  }

  /**
   * Roll a skill check.
   * successChance ≈ 35% + skill*18% - diff*12% (+/- risk flavor)
   */
  roll(skillId, diff = 1, risk) {
    const level = this.state.skill(skillId);
    let chance = 0.35 + level * 0.18 - diff * 0.12;
    if (typeof risk === "number") {
      // risk is displayed % failure-ish; blend lightly
      chance = chance * 0.7 + (1 - risk / 100) * 0.3;
    }
    chance = Math.max(0.08, Math.min(0.92, chance));
    const roll = Math.random();
    return {
      ok: roll <= chance,
      chance: Math.round(chance * 100),
      roll,
      skillId,
      level,
    };
  }

  applyNodeRewards(node) {
    if (!node) return;
    (node.gainItems || []).forEach((id) => this.state.addItem(id));
    if (node.gainXp) {
      Object.entries(node.gainXp).forEach(([skill, amt]) =>
        this.state.addSkillXp(skill, amt)
      );
    }
    if (typeof node.prestige === "number") {
      this.state.prestige = Math.max(0, this.state.prestige + node.prestige);
    }
    (node.flags || []).forEach((f) => this.state.setFlag(f));
    if (node.ending) {
      this.state.campaignDone = true;
      this.state.ending = node.ending;
    }
  }

  enter(nodeId) {
    const node = this.story.nodes[nodeId];
    if (!node) return null;
    this.state.campaignNode = nodeId;
    this.state.tickTime(8);
    if (!this.state.visitedNodes.has(nodeId)) {
      this.state.visitedNodes.add(nodeId);
      this.applyNodeRewards(node);
    } else if (node.ending) {
      this.state.campaignDone = true;
      this.state.ending = node.ending;
    }
    return node;
  }

  choose(choice) {
    if (choice.next) {
      return { node: this.enter(choice.next), check: null };
    }

    if (choice.skill) {
      const check = this.roll(choice.skill, choice.diff || 1, choice.risk);
      let target = check.ok ? choice.success : choice.fail;
      if (!check.ok && choice.requireFlag && !this.state.hasFlag(choice.requireFlag) && choice.alt) {
        target = choice.alt;
      }
      if (check.ok) this.state.addSkillXp(choice.skill, 1);
      return { node: this.enter(target), check };
    }

    return { node: this.node(), check: null };
  }

  sideMissionResult(mission) {
    const check = this.roll(mission.skill, mission.diff || 1);
    this.state.tickTime(12);
    if (check.ok) {
      this.state.addSkillXp(mission.xpSkill || mission.skill, 1);
      this.state.prestige = Math.max(0, this.state.prestige + (mission.prestige || 1));
      if (!this.state.missionsDone.includes(mission.id)) {
        this.state.missionsDone.push(mission.id);
      }
    } else {
      this.state.prestige = Math.max(0, this.state.prestige);
    }
    return check;
  }
}
